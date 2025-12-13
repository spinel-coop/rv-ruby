# Portable Ruby Binaries

Tools to build versions of Ruby that can be installed and run from anywhere on the filesystem.

## How do I use these rubies

These are general-purpose portable Ruby binaries. Download the appropriate tarball for your platform from the [releases page](https://github.com/jdx/ruby/releases) and extract it to any location.

## Local development

- Run `bin/setup` to tap your checkout of this repo as `jdx/ruby`.
- Run e.g. `brew jdx-package --no-uninstall-deps --debug --verbose jdx-ruby@3.4.5` to build Ruby 3.4.5 locally with YJIT.

## How do I issue a new release

[An automated release workflow is available to use](https://github.com/jdx/ruby/actions/workflows/release.yml).
Dispatch the workflow and all steps of building, tagging and uploading should be handled automatically.

<details>
<summary>Manual steps are documented below.</summary>

### Build

Run `brew portable-package ruby`. For macOS, this should ideally be inside an OS X 10.11 VM (so it is compatible with all working Homebrew macOS versions).

### Upload

Copy the bottle `bottle*.tar.gz` and `bottle*.json` files into a directory on your local machine.

Upload these files to GitHub Packages with:

```sh
brew pr-upload --upload-only --root-url=https://ghcr.io/v2/jdx/ruby
```

And to GitHub releases:

```sh
brew pr-upload --upload-only --root-url=https://github.com/jdx/ruby/releases/download/$VERSION
```

where `$VERSION` is the new package version.
</details>

## Thanks

Forked from [spinel-coop/rv-ruby](https://github.com/spinel-coop/rv-ruby), which was based on [Homebrew/homebrew-portable-ruby](https://github.com/Homebrew/homebrew-portable-ruby).

## License

Code is under the [BSD 2-Clause "Simplified" License](/LICENSE.txt).
