# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "development_tools"
require "dependency"

module Homebrew
  module Cmd
    class PortablePackageCmd < AbstractCommand
      cmd_args do
        usage_banner <<~EOS
          `portable-package` <formulae>

          Build and package portable formulae.
        EOS
        switch "--no-uninstall-deps",
               description: "Don't uninstall all dependencies of portable formulae before testing."
        switch "-v", "--verbose",
               description: "Pass `--verbose` to `brew` commands."
        switch "--with-yjit",
               description: "Build Ruby with YJIT included (the default)."
        switch "--without-yjit",
               description: "Build Ruby without YJIT included."
        named_args :formula, min: 1
      end

      sig { override.void }
      def run
        ENV["HOMEBREW_DEVELOPER"] = "1"

        verbose = []
        verbose << "--verbose" if args.verbose?
        verbose << "--debug" if args.debug?

        yjit = args.without_yjit? ? "--without-yjit" : "--with-yjit"

        # If test-bot cleanup is performed and auto-updates are disabled, this might not already be installed.
        unless DevelopmentTools.ca_file_handles_most_https_certificates?
          safe_system HOMEBREW_BREW_FILE, "install", "ca-certificates"
        end

        args.named.each do |name|
          begin
            # On Linux, install glibc and linux-headers from bottles and don't install their build dependencies.
            bottled_dep_allowlist = /\A(?:glibc@|linux-headers@|rustup)/
            deps = Dependency.expand(Formula[name], cache_key: "rv-package-#{name}") do |_dependent, dep|
              Dependency.prune if dep.test? || dep.optional?
              Dependency.prune if dep.name == "rustup" && args.without_yjit?

              next unless bottled_dep_allowlist.match?(dep.name)

              Dependency.keep_but_prune_recursive_deps
            end.map(&:name)

            bottled_deps, deps = deps.partition { |dep| bottled_dep_allowlist.match?(dep) }
            puts "Bottled deps: #{bottled_deps.inspect}"
            puts "Other deps: #{deps.inspect}"

            safe_system HOMEBREW_BREW_FILE, "install", *verbose, *bottled_deps if bottled_deps.present?

            # Build bottles for all other dependencies.
            safe_system HOMEBREW_BREW_FILE, "install", "--build-bottle", *verbose, *deps

            safe_system HOMEBREW_BREW_FILE, "install", "--build-bottle", yjit, *verbose, name
            unless args.no_uninstall_deps?
              safe_system HOMEBREW_BREW_FILE, "uninstall", "--force", "--ignore-dependencies", *verbose, *deps
            end
            safe_system HOMEBREW_BREW_FILE, "test", *verbose, name
            puts "Linkage information:"
            safe_system HOMEBREW_BREW_FILE, "linkage", *verbose, name
            bottle_args = %w[
              --skip-relocation
              --root-url=https://ghcr.io/v2/spinel-coop/rv-ruby
              --json
              --no-rebuild
            ]
            safe_system HOMEBREW_BREW_FILE, "bottle", *verbose, *bottle_args, name

            update_bottle_names name, args.without_yjit?
          rescue => e
            ofail e
          end
        end
      end

      def update_bottle_names(name, disable_yjit)
        Dir.glob("*.bottle.json").each do |j|
          json = File.read j
          json.gsub! "#{name}--", "ruby-"
          json.gsub! ERB::Util.url_encode(name), "ruby"
          File.write j, json
        end

        yjit_tag = disable_yjit ? ".no_yjit." : "."
        Dir.glob("#{name}*").each do |f|
          r = f.gsub("#{name}--", "ruby-")
          r = r.gsub(".bottle.", yjit_tag)
          FileUtils.mv f, r
        end
      end
    end
  end
end
