# frozen_string_literal: true

module PortableFormulaMixin
  if OS.mac?
    if Hardware::CPU.arm?
      TARGET_MACOS = :sonoma
    else
      TARGET_MACOS = :sequoia
    end
  end

  def install
    if OS.mac?
      if OS::Mac.version > TARGET_MACOS
        target_macos_humanized = TARGET_MACOS.to_s.tr("_", " ").split.map(&:capitalize).join(" ")

        opoo <<~EOS
          You are building portable formula on #{OS::Mac.version}.
          As result, formula won't be able to work on older macOS versions.
          It's recommended to build this formula on macOS #{target_macos_humanized}
          (the oldest version that can run Homebrew).
        EOS
      end

      # Always prefer to linking to portable libs.
      ENV.append "LDFLAGS", "-Wl,-search_paths_first"
    elsif OS.linux?
      # We want our Ruby to link against generic linux glibc etc,
      # not against the Homebrew-provided glibc etc, for portability.
      # To ensure that, we clear out all the env vars Homebrew uses
      # to redirect links to the Homebrew-provided libs instead.
      %w[
        LDFLAGS LIBRARY_PATH LD_RUN_PATH LD_LIBRARY_PATH
        TERMINFO_DIRS HOMEBREW_RPATH_PATHS HOMEBREW_DYNAMIC_LINKER
      ].each { |k| ENV.delete(k) }

      # By forcing the OS-level tools, we avoid the possibility that our
      # Ruby binaries will link against the Homebrew-provided libs.
      ENV["CC"] = "/usr/bin/cc"
      ENV["CXX"] = "/usr/bin/c++"
      ENV["CPP"] = "/usr/bin/cpp"

      # We don't clear PATH or PKG_CONFIG_PATH, because we also need some
      # brew-provided tools (like autoconf and pkgconf), plus the portable-*
      # libs that we are going to link statically.

      # https://github.com/Homebrew/homebrew-portable-ruby/issues/118
      ENV.append_to_cflags "-fPIC"
    end

    super
  end

  def test
    refute_match(/Homebrew libraries/,
                 shell_output("#{HOMEBREW_BREW_FILE} linkage #{full_name}"))

    super
  end
end

class PortableFormula < Formula
  desc "Abstract portable formula"
  homepage "https://github.com/spinel-coop/rv-ruby"

  def self.inherited(subclass)
    subclass.class_eval do
      super

      keg_only "portable formulae are keg-only"

      on_linux do
        depends_on "glibc@2.17" => :build
        depends_on "linux-headers@4.4" => :build
      end

      prepend PortableFormulaMixin
    end
  end
end
