# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "development_tools"
require "dependency"

module Homebrew
  module Cmd
    class RvPackageCmd < AbstractCommand
      cmd_args do
        usage_banner <<~EOS
          `rv-package` <formulae>

          Build and package rv formulae.
        EOS
        switch "--no-uninstall-deps",
               description: "Don't uninstall all dependencies of portable formulae before testing."
        switch "-v", "--verbose",
               description: "Pass `--verbose` to `brew` commands."
        switch "--without-yjit",
               description: "Build Ruby without YJIT included."
        named_args :formula, min: 1
      end

      def prune
        if defined?(Dependable::PRUNE)
          Dependable::PRUNE
        else
          Dependency.prune
        end
      end

      def keep_but_prune_recursive_deps
        if defined?(Dependable::KEEP_BUT_PRUNE_RECURSIVE_DEPS)
          Dependable::KEEP_BUT_PRUNE_RECURSIVE_DEPS
        else
          Dependency.keep_but_prune_recursive_deps
        end
      end

      sig { override.void }
      def run
        ENV["HOMEBREW_DEVELOPER"] = "1"

        verbose = []
        verbose << "--verbose" if args.verbose?
        verbose << "--debug" if args.debug?

        flags = []
        flags << "--without-yjit" if args.without_yjit?

        # If test-bot cleanup is performed and auto-updates are disabled, this might not already be installed.
        unless DevelopmentTools.ca_file_handles_most_https_certificates?
          safe_system HOMEBREW_BREW_FILE, "install", "ca-certificates"
        end

        args.named.each do |name|
          flags << "--HEAD" unless name.include?("@")

          begin
            # Install build deps (but not static-linked deps) from bottles, to save compilation time
            static_deps = /portable-/
            deps = Dependency.expand(Formula[name], cache_key: "rv-package-#{name}") do |_dependent, dep|
              next prune if dep.test? || dep.optional?
              next prune if dep.name == "rustup" && args.without_yjit?

              next if static_deps.match?(dep.name)

              keep_but_prune_recursive_deps
            end.map(&:name)

            deps, bottled_deps = deps.partition { |dep| static_deps.match?(dep) }
            puts "Bottled deps: #{bottled_deps.inspect}"
            puts "Compiled deps: #{deps.inspect}"

            quiet_system HOMEBREW_BREW_FILE, "install", *verbose, *bottled_deps if bottled_deps.any?

            # Build bottles for all other dependencies.
            safe_system HOMEBREW_BREW_FILE, "install", "--build-bottle", *verbose, *deps if deps.any?
            # Build the main bottle
            safe_system HOMEBREW_BREW_FILE, "install", "--build-bottle", *flags, *verbose, name
            # Uninstall the dependencies we linked in
            unless args.no_uninstall_deps? || deps.empty?
              safe_system HOMEBREW_BREW_FILE, "uninstall", "--force", "--ignore-dependencies", *verbose, *deps
            end

            # On Ubuntu for ARM, the permissions are somehow wrong and `brew test` dies
            if File.exist? File.join(HOMEBREW_PREFIX, "Homebrew/Library/Homebrew/vendor/bundle")
              safe_system "bash", "-c", 'chmod -R +t $(brew --prefix)/Homebrew/Library/Homebrew/vendor/bundle'
              safe_system HOMEBREW_BREW_FILE, "install-bundler-gems"
            end

            # Test the static binary we just built, now that the separate deps have been deleted
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

            rename_bottles name, args.without_yjit?
          rescue => e
            ofail e
          end
        end
      end

      def rename_bottles(name, disable_yjit)
        yjit_tag = disable_yjit ? ".no_yjit." : "."

        Dir.glob("*.bottle.json").each do |j|
          commit = j.match(/-HEAD-([a-f0-9]+)/){|m|m[1]}

          json = File.read j
          json.gsub! "#{name}--", "ruby-"
          json.gsub!(/-HEAD-[a-f0-9]+/, "-dev")
          json.gsub!(".sequoia.", ".ventura.")
          json.gsub!(".bottle.", yjit_tag)
          json.gsub! ERB::Util.url_encode(name), "ruby"
          hash = JSON.parse(json)
          bottle_name = name.gsub(/^rv-/, "")
          hash[hash.keys.first]["formula"]["name"] = bottle_name
          hash[hash.keys.first]["formula"]["pkg_version"] = Date.today.to_s.tr("-", "")
          hash[hash.keys.first]["formula"]["pkg_version"] << "-" << commit if commit
          File.write j, JSON.generate(hash)
        end

        Dir.glob("#{name}*").each do |f|
          r = f.gsub("#{name}--", "ruby-")
          r = r.gsub(/-HEAD-[a-f0-9]+/, "-dev")
          r = r.gsub(".sequoia.", ".ventura.")
          r = r.gsub(".bottle.", yjit_tag)
          FileUtils.mv f, r
        end
      end
    end
  end
end
