# Installing prebuilt Nokogiri on JekyllEx (no on-device compile)

These gems are **precompiled** for Android ABIs with the Android NDK. Installing them does **not** run `extconf.rb` or need a C compiler on the device.

Distributed from: https://github.com/gouravkhunger/nokogiri-android  
Gem identity: platform gem named `nokogiri` (same require path as upstream), built and released under the **nokogiri-android** project.

## Requirements

| Item | Value |
|------|--------|
| App | [JekyllEx](https://github.com/jekyllex) (or Termux-style Android Ruby) |
| Ruby | Matches the gem’s Ruby minor (see release notes; fat path is `lib/nokogiri/X.Y/nokogiri.so`) |
| ABIs | `aarch64`, `arm`, `i686`, `x86_64` |
| System libs | Bootstrap must provide `libxml2`, `libxslt`, `libiconv`, `zlib` (JekyllEx ruby-android already does) |

## 1. Pick the gem for your ABI

| Device ABI | Gem platform suffix |
|------------|---------------------|
| arm64-v8a (most phones) | `aarch64-linux-android` |
| armeabi-v7a | `arm-linux-androideabi` |
| x86 | `i686-linux-android` |
| x86_64 | `x86_64-linux-android` |

Download `nokogiri-VERSION-PLATFORM.gem` from the [GitHub Releases](https://github.com/gouravkhunger/nokogiri-android/releases) (or CI artifacts).

## 2. Install inside JekyllEx

In the JekyllEx terminal (env already sets `GEM_HOME` / `GEM_PATH` to  
`/data/data/xyz.jekyllex/files/usr/lib/ruby/gems/3.3.0` on current bootstraps):

```bash
# copy the .gem into the app home, then:
gem install --local ~/nokogiri-VERSION-PLATFORM.gem --no-document
```

If Rubygems complains about platform mismatch:

```bash
gem install --local ~/nokogiri-VERSION-PLATFORM.gem --no-document --platform PLATFORM
```

Verify:

```bash
ruby -e 'require "nokogiri"; puts Nokogiri::VERSION'
```

## 3. Bundler / Jekyll projects

Keep **Prefer local gems** enabled in JekyllEx so `bundle install` does not try to fetch a source gem that needs compiling.

Pin the version you installed if needed:

```ruby
gem "nokogiri", "VERSION"
```

## Why this works

- Gemspec **`extensions` is empty** → Rubygems never runs a native build on install.
- Native code ships as `lib/nokogiri/<ruby_minor>/nokogiri.so` (upstream precompiled layout).
- `lib/nokogiri/extension.rb` loads that path first.

## Build from source (maintainers)

```bash
export NDK=/path/to/android-ndk-r27c   # or ANDROID_NDK_HOME
./scripts/build_android.sh aarch64
# → pkg/nokogiri-*-aarch64-linux-android.gem
./scripts/verify_gem.rb pkg/nokogiri-*-aarch64-linux-android.gem
```

Do **not** `gem push` or publish GitHub Releases without an explicit approval step.
