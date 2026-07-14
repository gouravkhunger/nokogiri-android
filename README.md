# nokogiri-android

Precompiled [Nokogiri](https://nokogiri.org) native gems for **Android ABIs**, so [JekyllEx](https://github.com/jekyllex) (and similar Termux-style Android Ruby environments) can install Nokogiri **without on-device compilation**.

Built with the **Android NDK** against Termux/JekyllEx-compatible `libxml2` / `libxslt` / Ruby headers.

## Status

| Item | Detail |
|------|--------|
| Upstream Nokogiri | git submodule → [sparklemotion/nokogiri](https://github.com/sparklemotion/nokogiri) |
| Toolchain | Android NDK r27c (CI), API 24+ |
| ABIs | `aarch64`, `arm`, `i686`, `x86_64` |
| Output | `pkg/nokogiri-VERSION-<android-platform>.gem` (prebuilt; empty `extensions`) |
| Distribution | GitHub Releases / CI artifacts under this repo (**not** auto-pushed to RubyGems.org) |

## Install (JekyllEx users)

See **[INSTALL.md](./INSTALL.md)** for device install steps.

Short version:

```bash
gem install --local nokogiri-VERSION-aarch64-linux-android.gem --no-document
ruby -e 'require "nokogiri"; puts Nokogiri::VERSION'
```

## Build

```bash
git clone --recursive https://github.com/gouravkhunger/nokogiri-android.git
cd nokogiri-android
export NDK=$ANDROID_NDK_HOME   # NDK r27+ with llvm toolchain
./scripts/build_android.sh aarch64
./scripts/verify_gem.rb pkg/nokogiri-*-aarch64-linux-android.gem
```

| Script | Role |
|--------|------|
| `setup.sh` | Download Termux debs (Ruby/xml/xslt/zlib), export NDK env |
| `scripts/cross_compile.rb` | Cross-compile extension with target RbConfig + NDK clang |
| `scripts/package_gem.rb` | Pack platform gem with `lib/nokogiri/X.Y/nokogiri.so`, no extensions |
| `scripts/build_android.sh` | setup → compile → package |
| `scripts/verify_gem.rb` | Assert prebuilt layout / ELF / metadata |

CI: `.github/workflows/build.yml` (matrix of all four ABIs, uploads `.gem` artifacts).

## Gem identity

- **Rubygems name:** `nokogiri` (so `require "nokogiri"` and `gem "nokogiri"` keep working)
- **Platform:** e.g. `aarch64-linux-android` (not linux-gnu)
- **Project / distribution name:** **nokogiri-android** (this repository)
- Gems include `NOKOGIRI_ANDROID.txt` and metadata `nokogiri_android=true`

Publishing to RubyGems.org would collide with upstream naming policy; preferred channel is **GitHub Releases** from this repo. No public release or `gem push` without maintainer approval.

## Layout of a prebuilt gem

```
lib/nokogiri.rb
lib/nokogiri/extension.rb
lib/nokogiri/3.4/nokogiri.so    # Ruby minor ABI
lib/nokogiri/**/*.rb
NOKOGIRI_ANDROID.txt
# gemspec: platform=aarch64-linux-android, extensions=[]
```

## License

Nokogiri is MIT (see submodule `LICENSE.md`). This packaging glue is also MIT.
