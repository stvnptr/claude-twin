#!/bin/bash
# Sandboxed tests for scripts/setup.sh. Installs into a temp folder, never into
# ~/Applications, and never refreshes the Dock. Uses a stub Claude.app when the
# real one isn't installed (e.g. on CI); the icon test runs only with the real app.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SETUP="$ROOT/scripts/setup.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export APPS_DIR="$TMP/Applications" SKIP_REFRESH=1

if [ -z "${CLAUDE_APP:-}" ]; then
  if [ -d /Applications/Claude.app ]; then
    CLAUDE_APP=/Applications/Claude.app
  else
    CLAUDE_APP="$TMP/Claude.app"
    mkdir -p "$CLAUDE_APP/Contents/Resources"
    /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string missing.icns' "$CLAUDE_APP/Contents/Info.plist" >/dev/null
  fi
fi
export CLAUDE_APP

PASS=0 FAIL=0
ok()   { echo "ok   - $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL - $1"; FAIL=$((FAIL + 1)); }
check() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$desc"; else fail "$desc"; fi; }
check_not() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then fail "$desc"; else ok "$desc"; fi; }

L="$APPS_DIR/Claude - Test Profile.app"
script_of() { osadecompile "$1/Contents/Resources/Scripts/main.scpt"; }

check "--help exits 0" bash "$SETUP" --help
check "--version exits 0" bash "$SETUP" --version
check_not "unknown option fails" bash "$SETUP" --bogus
check_not "invalid name is rejected" bash "$SETUP" --name 'x;rm -rf'
check_not "non-numeric hue is rejected" bash "$SETUP" --hue abc
check_not "missing --name value fails" bash "$SETUP" --name

check "dry run succeeds" bash "$SETUP" --name "Test Profile" --dry-run
check_not "dry run creates nothing" test -e "$L"

check "install succeeds" bash "$SETUP" --name "Test Profile" --no-icon
check "launcher exists" test -d "$L"
check "launcher signature is valid" codesign --verify "$L"
check "launcher uses its own data dir" bash -c "osadecompile \"$L/Contents/Resources/Scripts/main.scpt\" | grep -q 'user-data-dir=.*Application Support/Claude-Test-Profile'"
check "launcher uses its own config dir" bash -c "osadecompile \"$L/Contents/Resources/Scripts/main.scpt\" | grep -q 'CLAUDE_CONFIG_DIR=.*\.claude-test-profile'"
check "launcher points at Claude.app" bash -c "osadecompile \"$L/Contents/Resources/Scripts/main.scpt\" | grep -qF -- '-a \\\"$CLAUDE_APP\\\"'"

PATTERN="$(script_of "$L" | sed -n "s/.*pgrep -a -f '\([^']*\)'.*/\1/p")"
check "duplicate guard matches its own instance" bash -c "echo '/Applications/Claude.app/Contents/MacOS/Claude --user-data-dir=/Users/x/Library/Application Support/Claude-Test-Profile' | grep -Eq \"\$1\"" _ "$PATTERN"
check_not "duplicate guard ignores other profiles" bash -c "echo '/Applications/Claude.app/Contents/MacOS/Claude --user-data-dir=/Users/x/Library/Application Support/Claude-Test-Profile2' | grep -Eq \"\$1\"" _ "$PATTERN"

check "re-run replaces own launcher" bash "$SETUP" --name "Test Profile" --no-icon

mkdir -p "$APPS_DIR/Claude - Foreign.app/Contents"
check_not "refuses to overwrite a foreign app" bash "$SETUP" --name Foreign --no-icon
check_not "refuses to uninstall a foreign app" bash "$SETUP" --name Foreign --uninstall
check "foreign app is left alone" test -d "$APPS_DIR/Claude - Foreign.app"

check "uninstall succeeds" bash "$SETUP" --name "Test Profile" --uninstall
check_not "launcher is gone" test -e "$L"
check_not "uninstall of missing launcher fails" bash "$SETUP" --name "Test Profile" --uninstall

if [ "$CLAUDE_APP" = /Applications/Claude.app ] && command -v swift >/dev/null 2>&1; then
  check "install with icon succeeds" bash "$SETUP" --name "Icon" --hue 2.2
  check "icon file was written" test -s "$APPS_DIR/Claude - Icon.app/Contents/Resources/applet.icns"
  check_not "generic icon name removed" /usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$APPS_DIR/Claude - Icon.app/Contents/Info.plist"
  check "icon launcher signature is valid" codesign --verify "$APPS_DIR/Claude - Icon.app"
else
  check "icon step degrades gracefully without the real app" bash "$SETUP" --name "Icon"
  echo "skip - icon rendering (needs the real Claude.app and swift)"
fi

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
