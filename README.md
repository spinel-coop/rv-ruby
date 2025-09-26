# rv ruby binaries

Tools to build versions of Ruby that can be installed and run from anywhere on the filesystem.

## How do I use these rubies

First, [install `rv`](https://github.com/spinel-coop/rv), and then run `rv ruby install`.

## How do I issue a new release

[An automated release workflow is available to use](https://github.com/spinel-coop/rv-ruby/actions/workflows/release.yml).
Dispatch the workflow and all steps of building, tagging and uploading should be handled automatically.

<details>
<summary>Manual steps are documented below.</summary>

### Build

Run `brew portable-package ruby`. For macOS, this should ideally be inside an OS X 10.11 VM (so it is compatible with all working Homebrew macOS versions).

### Upload

Copy the bottle `bottle*.tar.gz` and `bottle*.json` files into a directory on your local machine.

Upload these files to GitHub Packages with:

```sh
brew pr-upload --upload-only --root-url=https://ghcr.io/v2/spinel-coop/rv-ruby
```

And to GitHub releases:

```sh
brew pr-upload --upload-only --root-url=https://github.com/spinel-coop/rv-ruby/releases/download/$VERSION
```

where `$VERSION` is the new package version.
</details>

### Developing locally
<details>

<summary>Steps for developing locally are documented below</summary>

```sh
# make sure you have Homebrew installed 
git clone https://github.com/spinel-coop/rv-ruby
git tap <any_arbitrary_username>/portable-packages ./rv-ruby
# the commands in this package are now available
brew portable-package ruby
```
</details>

## Thanks

Thanks to the [Homebrew](https://brew.sh) team for the [portable-ruby](https://github.com/Homebrew/homebrew-portable-ruby) code we used as a starting point.

## License

Code is under the [BSD 2-Clause "Simplified" License](/LICENSE.txt).
