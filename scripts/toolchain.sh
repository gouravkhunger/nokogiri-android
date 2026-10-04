#!/usr/bin/env bash
# Create $STAGE/bin wrappers: $TARGET-ar/clang/... for mini_portile --host=$TARGET
set -euo pipefail
: "${STAGE_DIR:?}" "${TARGET:?}" "${NOKOGIRI_ANDROID_REAL_CC:?}" "${NOKOGIRI_ANDROID_REAL_CXX:?}" "${AR:?}" "${RANLIB:?}" "${STRIP:?}"
BIN="$STAGE_DIR/bin"
mkdir -p "$BIN"
wrap() { # name -> real
  cat > "$BIN/$1" << W
#!/usr/bin/env bash
exec "$2" "\$@"
W
  chmod +x "$BIN/$1"
}
wrap "${TARGET}-ar" "$AR"
wrap "${TARGET}-ranlib" "$RANLIB"
wrap "${TARGET}-strip" "$STRIP"
wrap "${TARGET}-clang" "$NOKOGIRI_ANDROID_REAL_CC"
wrap "${TARGET}-clang++" "$NOKOGIRI_ANDROID_REAL_CXX"
wrap "${TARGET}-gcc" "$NOKOGIRI_ANDROID_REAL_CC"
wrap "${TARGET}-g++" "$NOKOGIRI_ANDROID_REAL_CXX"
# bare names some recipes expect
wrap ar "$AR"
wrap ranlib "$RANLIB"
wrap strip "$STRIP"
export PATH="$BIN:$PATH"
