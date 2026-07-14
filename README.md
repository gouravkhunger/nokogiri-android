# nokogiri-android

Prebuilt [Nokogiri](https://nokogiri.org) gems for Android ABIs (JekyllEx / Termux-style Ruby). No on-device compile.

## Build

```bash
export NDK=/path/to/ndk   # r27+
./scripts/build.sh aarch64   # arm | i686 | x86_64
# → pkg/nokogiri-VERSION-PLATFORM.gem
```

CI: `.github/workflows/build.yml` (4 ABIs, artifact upload only).

## Install (device)

```bash
gem install --local nokogiri-VERSION-PLATFORM.gem --no-document
```

## Layout

| Path | Role |
|------|------|
| `nokogiri/` | upstream submodule (pin with git tag per release) |
| `patches/` | optional diffs applied for that tag |
| `scripts/stage.sh` | Android MRI (+ shared libs today) into `stage/<arch>` |
| `scripts/compile.rb` | NDK cross-compile extension |
| `scripts/package.rb` | platform gem, `extensions=[]`, `lib/nokogiri/X.Y/nokogiri.so` |
| `scripts/build.sh` | stage → compile → package → verify |

## Termux?

**Not required as a runtime or as “bindings.”**  
Debs are only a **convenient source** of Android `ruby` headers/`libruby` (and currently shared libxml2/xslt for the dynamic link path).

| Piece | Need Termux? |
|-------|----------------|
| libxml2 / libxslt / zlib in the gem | **No** — future: NDK/mini_portile **static into `.so`** per nokogiri version |
| Android MRI headers + `libruby` to link the ext | **Some** prebuilt Android Ruby (Termux deb, JekyllEx bootstrap zip, …) |
| On-device install | No Termux app; JekyllEx-style prefix is enough |

## Versioning

- One git tag per published line (e.g. `v1.18.8-android.1`) pins `nokogiri` submodule + `patches/`.
- Future releases **bundle** libxml2/libxslt/zlib inside `nokogiri.so` so gem version ≠ device lib versions.

## Size

Dynamic link (today) ≈ 300–500 KB gem. Upstream fat gems ≈ multi‑MB: static C stack + multiple Ruby ABIs.

## License

MIT (see `nokogiri/LICENSE.md`).
