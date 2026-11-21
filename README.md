# rv ruby binaries

Tools to build versions of Ruby that can be installed and run from anywhere on the filesystem.

## How do I use these rubies

First, [install `rv`](https://github.com/spinel-coop/rv), and then run `rv ruby install`.

## Local development

- Run `bin/setup` to tap your checkout of this repo as `spinel-coop/rv-ruby`.
- Run e.g. `bin/package 3.4.5` to build Ruby 3.4.5 locally with YJIT.
- Run e.g. `bin/package-alpine rv-ruby@3.4.5` to use Docker to build Ruby 3.4.5 on Alpine Linux with musl libc.

## Sanitizer builds

Ruby 3.4 and later can also be built with AddressSanitizer and UndefinedBehaviorSanitizer, for finding memory errors in Ruby and in native extensions. These builds are much slower and are never installed by default.

- Run e.g. `bin/package 4.0.9 --with-sanitizers` to build one locally. It needs Homebrew's `llvm`, and produces `ruby-4.0.9.<platform>.asan_ubsan.tar.gz`.
- Dispatch the release workflow with `sanitizers` checked to add them to a release, for macOS and glibc Linux. ASan doesn't support musl, so there are no Alpine sanitizer builds.
- On macOS, the ASan runtime is shipped in `lib/` next to Ruby.
- Native gems are compiled with the sanitizer flags, which needs clang 18 or later. On Linux any `clang` on `PATH` works. On macOS it must be Homebrew's (`brew install llvm`), because Apple clang's ASan instrumentation is incompatible with the LLVM runtime.

## How are new Ruby versions added

Every day, the [bump workflow](https://github.com/spinel-coop/rv-ruby/actions/workflows/bump.yml) checks ruby-lang.org for new releases and opens a pull request with a formula for each one. The pull request merges on its own once the new Ruby builds on every platform. If a build fails, it stays open until someone fixes or closes it.

To write the formula yourself, run `bin/rv-bump write`. Run `test/rv-bump-test` after changing `bin/rv-bump`.

## How do I issue a new release

[The release workflow](https://github.com/spinel-coop/rv-ruby/actions/workflows/release.yml) runs whenever a formula or abstract changes on `main`.
It rebuilds every Ruby, then tags and uploads them as a release named for the date. A second release on the same day gets a tag ending in `-2`.

A release that fails partway leaves its tag behind as a prerelease, and the next run takes the next number. Delete the leftover with `gh release delete <tag> --cleanup-tag`.

You can also dispatch the workflow yourself.

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

## Thanks

Thanks to the [Homebrew](https://brew.sh) team for the [portable-ruby](https://github.com/Homebrew/homebrew-portable-ruby) code we used as a starting point.

## License

Code is under the [BSD 2-Clause "Simplified" License](/LICENSE.txt).
