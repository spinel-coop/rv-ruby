# typed: strict
# frozen_string_literal: true

# Opt-in AddressSanitizer + UndefinedBehaviorSanitizer builds (`--with-sanitizers`), for finding
# memory errors in Ruby and in native extensions. These are slow and are never the default.
#
# Follows https://github.com/ruby/ruby/blob/master/doc/contributing/debugging_ruby.md: ASan needs
# clang >= 18, and Ruby >= 3.4 for GC stack scanning that understands ASan's fake stacks. Ruby
# compiles in its own `__asan_default_options` (detect_leaks=0, use_sigaltstack=0).
module RvRubySanitizers
  # Ruby calls C functions through casted `ANYARGS` pointers, does deliberate unaligned loads,
  # and routinely passes NULL with a zero length to `memcpy` and friends, so these UBSan checks
  # only produce noise.
  CFLAGS = %w[
    -fsanitize=address,undefined
    -fno-sanitize=function,alignment,nonnull-attribute
    -fno-omit-frame-pointer
  ].freeze

  ASAN_RUNTIME = "libclang_rt.asan_osx_dynamic.dylib"

  def sanitizer_llvm
    Formula["llvm"]
  end

  def sanitizer_configure_args
    %W[
      CC=#{sanitizer_llvm.opt_bin}/clang
      CXX=#{sanitizer_llvm.opt_bin}/clang++
    ]
  end

  def append_sanitizer_flags
    ENV.append "cflags", CFLAGS.join(" ")
    # Clang's thread-local codegen breaks M:N threads under ASan: https://bugs.ruby-lang.org/issues/20243
    ENV.append "cppflags", "-DUSE_MN_THREADS=0"
  end

  # Native gems must be compiled by a clang whose ASan instrumentation matches the runtime.
  # Any clang >= 18 on Linux works, but Apple clang emits an Apple-specific ASan version check
  # that the LLVM runtime doesn't export, so macOS keeps Homebrew's LLVM clang (`brew install llvm`).
  def fix_sanitizer_rbconfig(rbconfig)
    inreplace rbconfig, "#{sanitizer_llvm.opt_bin}/", "" if OS.linux?
  end

  # On Linux the sanitizer runtimes are linked statically into `ruby`. macOS only has a dynamic
  # ASan runtime (which also contains UBSan), so ship it in the keg and point every Mach-O at it.
  def bundle_sanitizer_runtime
    return unless OS.mac?

    runtime = Dir[sanitizer_llvm.opt_lib/"clang/*/lib/darwin/#{ASAN_RUNTIME}"].first
    odie "Could not find #{ASAN_RUNTIME} in #{sanitizer_llvm.opt_lib}" unless runtime
    bundled = lib/ASAN_RUNTIME
    cp runtime, bundled
    chmod 0644, bundled
    bundled.change_dylib_id("@executable_path/../lib/#{ASAN_RUNTIME}")
    MachO.codesign!(bundled.to_s)

    prefix.glob("**/*").each do |file|
      next if file.symlink? || !file.file? || file == bundled
      next if !file.mach_o_executable? && !file.dylib? && !file.mach_o_bundle?

      linked = file.dynamically_linked_libraries(resolve_variable_references: false)
                   .select { |name| name.end_with?("/#{ASAN_RUNTIME}") }
      build_rpaths = file.rpaths(resolve_variable_references: false)
                         .select { |rpath| rpath.start_with?("#{HOMEBREW_PREFIX}/") }
      next if linked.empty? && build_rpaths.empty?

      # Not `Utils::Path.ensure_writable`: it's missing from the older Homebrew on GitHub's macOS images.
      saved_mode = file.stat.mode
      file.chmod(saved_mode | 0200)
      begin
        linked.each { |old| file.change_install_name(old, "@executable_path/../lib/#{ASAN_RUNTIME}") }
        build_rpaths.each { |rpath| file.delete_rpath(rpath) }
        MachO.codesign!(file.to_s)
      ensure
        file.chmod(saved_mode)
      end
    end
  end
end
