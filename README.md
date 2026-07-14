# nokogiri-android

Prebuilt [Nokogiri](https://nokogiri.org) platform gems for Android ABIs.
Native deps (libxml2, libxslt, zlib, libiconv, gumbo) are **built and static-linked** into `nokogiri.so` per Nokogiri version. Install needs no C compiler and no matching system libxml.

## Build

```bash
export NDK=/path/to/ndk-r27+
./scripts/build.sh aarch64   # arm | i686 | x86_64
# → pkg/nokogiri-VERSION-PLATFORM.gem
```

Needs: NDK, host Ruby ~3.4, `dpkg-deb`, network (downloads dep tarballs once into `nokogiri/ports/`).

Android MRI headers/`libruby` come from a Termux ruby `.deb` (convenience only). Not used for libxml/xslt.

## Install

```bash
gem install --local nokogiri-VERSION-PLATFORM.gem --no-document
```

## Layout

| Path | Role |
|------|------|
| `nokogiri/` | upstream submodule (pin per release tag) |
| `patches/<version>/` | applied onto submodule at build |
| `scripts/build.sh` | entry |
| `scripts/stage.sh` | NDK env + Android Ruby only |
| `scripts/compile.rb` | mini_portile static cross-build + link |
| `scripts/package.rb` | platform gem, `extensions=[]` |

## Versioning

Git tag (e.g. `v1.18.8-android.1`) pins submodule + `patches/`. CI builds four ABIs and uploads `.gem` artifacts.

## Size

Static `.so` ~3 MB; gem ~1.5–2 MB (one Ruby ABI). Upstream fat gems are larger (multiple Ruby ABIs + same static idea).

## License

MIT — see `nokogiri/LICENSE.md`.
