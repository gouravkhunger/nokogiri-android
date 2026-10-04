# nokogiri-android

[![CI](https://github.com/gouravkhunger/nokogiri-android/actions/workflows/build.yml/badge.svg)](https://github.com/gouravkhunger/nokogiri-android/actions/workflows/build.yml)

Prebuilt [Nokogiri](https://nokogiri.org) platform gems for Android / [JekyllEx](https://github.com/jekyllex).
Static libxml2, libxslt, zlib, libiconv, and gumbo in `nokogiri.so`. Target **Ruby 3.3** (JekyllEx bootstrap).

The gem is named `nokogiri`. Download it from a GitHub Release and install it locally. That replaces the copy bundled in JekyllEx. `require "nokogiri"` then loads this version.

| ABI | Gem platform |
|-----|----------------|
| aarch64 | `aarch64-linux-android` |
| arm | `arm-linux-androideabi` |
| i686 | `i686-linux-android` |
| x86_64 | `x86_64-linux-android` |

## Install

```bash
gem install --local nokogiri-VERSION-aarch64-linux-android.gem --no-document
ruby -e 'require "nokogiri"; p Nokogiri::VERSION'
```

`github-pages` allows `nokogiri < 2`. Extensions are empty, so RubyGems does not compile.

## Build

```bash
export NDK=/path/to/ndk-r29
./scripts/build.sh aarch64   # arm | i686 | x86_64
# → pkg/nokogiri-VERSION-aarch64-linux-android.gem
```

Android MRI 3.3.4 headers/`libruby` come from JekyllEx bootstrap zips (`v0.1.5` by default). Override with `JEKYLLEX_BOOTSTRAP_VERSION` or `RUBY_URL`.

The `.so` loads on JekyllEx Ruby 3.3.4 (`libruby.so.3.3`, 16 KB pages) with no on-device compile. It does not load on Termux Ruby 4.0.

## Release

Tag push runs the package test, builds four ABIs, and attaches the gems to a GitHub Release.

```bash
git tag -a v1.19.4 -m "1.19.4"
git push origin v1.19.4
```

Watch **Actions → Release**. The release has four `.gem` files. Rebuild an existing tag from Actions → **Release** → Run workflow.

## Workflows

| Workflow | Trigger | Role |
|----------|---------|------|
| **Build** | push / PR / manual | package test + 4-ABI build → artifacts |
| **Release** | tag `v*` / `x.y*` / manual | build → GitHub Release |

## Layout

| Path | Role |
|------|------|
| `nokogiri/` | upstream submodule |
| `patches/<version>/` | applied at build |
| `scripts/build.sh` | entry |
| `scripts/stage.sh` | NDK + JekyllEx Ruby 3.3.4 |
| `scripts/compile.rb` | static cross-build |
| `scripts/package.rb` | platform gem named `nokogiri` |
| `.github/workflows/build.yml` | CI |
| `.github/workflows/release.yml` | GitHub Release |

## License

MIT — `nokogiri/LICENSE.md`.
