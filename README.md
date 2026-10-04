# nokogiri-android

[![Gem Version](https://img.shields.io/gem/v/nokogiri-android)][ruby-gems]
[![Gem Total Downloads](https://img.shields.io/gem/dt/nokogiri-android)][ruby-gems]
[![CI](https://github.com/gouravkhunger/nokogiri-android/actions/workflows/build.yml/badge.svg)](https://github.com/gouravkhunger/nokogiri-android/actions/workflows/build.yml)

[ruby-gems]: https://rubygems.org/gems/nokogiri-android

Prebuilt [Nokogiri](https://nokogiri.org) **platform gems** for Android / [JekyllEx](https://github.com/jekyllex).
Static libxml2, libxslt, zlib, libiconv, gumbo in `nokogiri.so`. Target **Ruby 3.3** (JekyllEx bootstrap).

Published as **`nokogiri-android`** on [rubygems.org/profiles/gouravkhunger](https://rubygems.org/profiles/gouravkhunger) (same model as `jekyll-auto-authors`, `jekyll-hostname`, …). After install, `require "nokogiri"` still works.

| ABI | Gem platform |
|-----|----------------|
| aarch64 | `aarch64-linux-android` |
| arm | `arm-linux-androideabi` |
| i686 | `i686-linux-android` |
| x86_64 | `x86_64-linux-android` |

## Install

On device, install the gem named `nokogiri`. That upgrades the bootstrap's 1.16.7 in place. `github-pages` allows `nokogiri < 2`. Extensions are empty, so RubyGems does not compile.

```bash
gem install --local nokogiri-VERSION-aarch64-linux-android.gem --no-document
ruby -e 'require "nokogiri"; p Nokogiri::VERSION'
```

`nokogiri-android` is the same `.so` under a name that can be pushed to RubyGems. It does not replace a gem already named `nokogiri`.

## Build

```bash
export NDK=/path/to/ndk-r29
./scripts/build.sh aarch64   # arm | i686 | x86_64
# → pkg/nokogiri-VERSION-aarch64-linux-android.gem
# → pkg/nokogiri-android-VERSION-aarch64-linux-android.gem
```

Android MRI 3.3.4 headers/`libruby` come from JekyllEx bootstrap zips (`v0.1.5` by default). Override with `JEKYLLEX_BOOTSTRAP_VERSION` or `RUBY_URL`.

The `.so` loads on JekyllEx Ruby 3.3.4 (`libruby.so.3.3`, 16 KB pages) with no on-device compile. It does not load on Termux Ruby 4.0. `GEM_NAME=nokogiri-android` builds only the RubyGems name.

## CI/CD publish

Fully automated. **Tag push** runs: package test → 4-ABI build → GitHub Release → `gem push` all platforms to RubyGems.

### One-time setup

1. RubyGems API key with **push** scope (same account as jekyll gems).
2. Repo → **Settings → Secrets and variables → Actions** → New secret:
   - Name: `RUBYGEMS_API_KEY`
   - Value: the API key

### Cut a release

```bash
# version tracks upstream Nokogiri pin in the submodule
git tag -a v1.19.4 -m "1.19.4"
git push origin v1.19.4
```

Watch **Actions → Release**. On success:

- GitHub Release `v1.19.4` with 4 `.gem` assets
- https://rubygems.org/gems/nokogiri-android has those platform versions

Re-run / rebuild a tag: Actions → **Release** → Run workflow → enter tag (optional uncheck “Also gem push” to only refresh GitHub Release).

## Workflows

| Workflow | Trigger | Role |
|----------|---------|------|
| **Build** | push / PR / manual | package test + 4-ABI build → artifacts |
| **Release** | tag `v*` / `x.y*` / manual | build → GitHub Release → **RubyGems `gem push`** |

## Layout

| Path | Role |
|------|------|
| `nokogiri/` | upstream submodule |
| `patches/<version>/` | applied at build |
| `scripts/build.sh` | entry |
| `scripts/stage.sh` | NDK + JekyllEx Ruby 3.3.4 |
| `scripts/compile.rb` | static cross-build |
| `scripts/package.rb` | platform gem (default name `nokogiri-android`) |
| `.github/workflows/build.yml` | CI |
| `.github/workflows/release.yml` | release + publish |

## License

MIT — `nokogiri/LICENSE.md`.
