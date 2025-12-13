# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "formula"
require "github_packages"
require "github_releases"
require "extend/hash/deep_merge"

module Homebrew
  module Cmd
    class JdxUploadCmd < AbstractCommand
      cmd_args do
        description <<~EOS
          Publish bottles to a host.
        EOS
        switch "--keep-old",
               description: "If the formula specifies a rebuild version, " \
                            "attempt to preserve its value in the generated DSL. " \
                            "When using GitHub Packages, this also appends the manifest to the existing list."
        switch "-n", "--dry-run",
               description: "Print what would be done rather than doing it."
        switch "--warn-on-upload-failure",
               description: "Warn instead of raising an error if the bottle upload fails. " \
                            "Useful for repairing bottle uploads that previously failed."
        flag   "--root-url=",
               description: "Use the specified <URL> as the root of the bottle's URL instead of Homebrew's default."
        flag   "--root-url-using=",
               description: "Use the specified download strategy class for downloading the bottle's URL instead of " \
                            "Homebrew's default."

        named_args :none
      end

      sig { override.void }
      def run
        json_files = Dir["ruby-*.json"]
        odie "No bottle JSON files found in the current working directory" if json_files.blank?

        Homebrew.install_bundler_gems!(groups: ["pr_upload"])

        bottles_hash = bottles_hash_from_json_files(json_files, args)

        if github_releases?(bottles_hash)
          github_releases = GitHubReleases.new
          github_releases.upload_bottles(bottles_hash)
        elsif github_packages?(bottles_hash)
          github_packages = GitHubPackages.new
          github_packages.upload_bottles(bottles_hash,
                                         keep_old:      args.keep_old?,
                                         dry_run:       args.dry_run?,
                                         warn_on_error: args.warn_on_upload_failure?)
        else
          odie "Service specified by root_url is not recognized"
        end
      end

      private

      sig { params(bottles_hash: T::Hash[String, T.untyped]).void }
      def check_bottled_formulae!(bottles_hash)
        bottles_hash.each do |name, bottle_hash|
          formula_path = HOMEBREW_REPOSITORY/bottle_hash["formula"]["path"]
          formula_version = Formulary.factory(formula_path).pkg_version
          bottle_version = PkgVersion.parse bottle_hash["formula"]["pkg_version"]
          next if formula_version == bottle_version

          odie "Bottles are for #{name} #{bottle_version} but formula is version #{formula_version}!"
        end
      end

      sig { params(bottles_hash: T::Hash[String, T.untyped]).returns(T::Boolean) }
      def github_releases?(bottles_hash)
        @github_releases ||= T.let(bottles_hash.values.all? do |bottle_hash|
          root_url = bottle_hash["bottle"]["root_url"]
          url_match = root_url.match GitHubReleases::URL_REGEX
          _, _, _, tag = *url_match

          tag
        end, T.nilable(T::Boolean))
      end

      sig { params(bottles_hash: T::Hash[String, T.untyped]).returns(T::Boolean) }
      def github_packages?(bottles_hash)
        @github_packages ||= T.let(bottles_hash.values.all? do |bottle_hash|
          bottle_hash["bottle"]["root_url"].match? GitHubPackages::URL_REGEX
        end, T.nilable(T::Boolean))
      end

      sig { params(json_files: T::Array[String], args: T.untyped).returns(T::Hash[String, T.untyped]) }
      def bottles_hash_from_json_files(json_files, args)
        puts "Reading JSON files: #{json_files.join(", ")}" if args.verbose?

        bottles_hash = json_files.reduce({}) do |hash, json_file|
          hash.deep_merge(JSON.parse(File.read(json_file)))
        end

        if args.root_url
          bottles_hash.each_value do |bottle_hash|
            bottle_hash["bottle"]["root_url"] = args.root_url
          end
        end

        bottles_hash
      end
    end
  end
end
