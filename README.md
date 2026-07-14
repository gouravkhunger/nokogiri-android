# nokogiri-android

Prebuilt [Nokogiri](https://nokogiri.org) platform gems for Android / [JekyllEx](https://github.com/jekyllex).
Static libxml2, libxslt, zlib, libiconv, gumbo in `nokogiri.so`. Target **Ruby 3.3** (JekyllEx bootstrap).

## Build

```bash
export NDK=/path/to/ndk-r27+
./scripts/build.sh aarch64   # arm | i686 | x86_64
# → pkg/nokogiri-VERSION-aarch64-linux-android.gem
#    lib/nokogiri/3.3/nokogiri.so
```

Android MRI 3.3.4 headers/`libruby` come from JekyllEx bootstrap zips (`v0.1.4` by default). Override with `JEKYLLEX_BOOTSTRAP_VERSION` or `RUBY_URL`.

## Install (JekyllEx)

```bash
gem install --local nokogiri-VERSION-PLATFORM.gem --no-document
ruby -e 'require "nokogiri"; p Nokogiri::VERSION'
```

## Layout

| Path | Role |
|------|------|
| `nokogiri/` | upstream submodule |
| `patches/<version>/` | applied at build |
| `scripts/build.sh` | entry |
| `scripts/stage.sh` | NDK + JekyllEx Ruby 3.3.4 |
| `scripts/compile.rb` | static cross-build |

## License

MIT — `nokogiri/LICENSE.md`.
