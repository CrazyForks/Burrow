#!/usr/bin/env bash
#
# Sign every executable inside a macOS app from the inside out, then seal the
# outer app with its entitlements. Release CI uses Developer ID mode; local
# source builds use ad-hoc mode so Full Disk Access can bind to a valid code
# identity without requiring maintainers to possess the distribution key.
#
set -euo pipefail

usage() {
  echo "usage: $0 <app-path> <identity> <developer-id|adhoc> [entitlements-path]" >&2
  exit 2
}

[ "$#" -ge 3 ] && [ "$#" -le 4 ] || usage

APP="$1"
IDENTITY="$2"
MODE="$3"
ENTITLEMENTS="${4:-macos/Resources/Burrow.entitlements}"

[ -d "$APP" ] || { echo "error: app not found: $APP" >&2; exit 1; }
[ -f "$ENTITLEMENTS" ] || { echo "error: entitlements not found: $ENTITLEMENTS" >&2; exit 1; }

case "$MODE" in
  developer-id)
    case "$IDENTITY" in
      "Developer ID Application:"*) ;;
      *)
        echo "error: release identity must start with 'Developer ID Application:'" >&2
        exit 1
        ;;
    esac
    SIGN_ARGS=(--force --options runtime --timestamp --sign "$IDENTITY")
    if [ -n "${CODESIGN_KEYCHAIN:-}" ]; then
      [ -f "$CODESIGN_KEYCHAIN" ] \
        || { echo "error: signing keychain not found: $CODESIGN_KEYCHAIN" >&2; exit 1; }
      SIGN_ARGS+=(--keychain "$CODESIGN_KEYCHAIN")
    fi
    ;;
  adhoc)
    [ "$IDENTITY" = "-" ] || { echo "error: ad-hoc mode requires identity '-'" >&2; exit 1; }
    SIGN_ARGS=(--force --sign -)
    ;;
  *)
    usage
    ;;
esac

sign_one() {
  local path="$1"
  codesign "${SIGN_ARGS[@]}" "$path"
}

is_macho() {
  file -b "$1" | grep -q "Mach-O"
}

echo "==> signing nested Mach-O files ($MODE)"
SIGNED_MACHO=0
while IFS= read -r -d '' candidate; do
  if is_macho "$candidate"; then
    sign_one "$candidate"
    SIGNED_MACHO=$((SIGNED_MACHO + 1))
  fi
done < <(find "$APP/Contents" -type f -print0)

# Re-seal code-bearing containers after their executables. `find -depth`
# guarantees an embedded app/XPC/framework is handled before its parent.
echo "==> signing nested code containers ($MODE)"
SIGNED_CONTAINERS=0
while IFS= read -r -d '' container; do
  sign_one "$container"
  SIGNED_CONTAINERS=$((SIGNED_CONTAINERS + 1))
done < <(
  find "$APP/Contents" -depth -type d \
    \( -name "*.framework" -o -name "*.xpc" -o -name "*.appex" \
       -o -name "*.app" -o -name "*.plugin" \) -print0
)

echo "==> sealing outer app ($MODE)"
codesign "${SIGN_ARGS[@]}" --entitlements "$ENTITLEMENTS" "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"

GET_TASK_ALLOW="$(
  codesign -d --entitlements :- "$APP" 2>/dev/null \
    | plutil -extract com.apple.security.get-task-allow raw -o - - 2>/dev/null \
    || true
)"
if [ "$GET_TASK_ALLOW" = "true" ]; then
  echo "error: release app contains com.apple.security.get-task-allow=true" >&2
  exit 1
fi

echo "signed $SIGNED_MACHO Mach-O file(s) and $SIGNED_CONTAINERS code container(s); strict verification passed"
