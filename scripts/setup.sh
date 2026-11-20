#!/bin/bash
# claude-twin: creates ~/Applications/"Claude - <Name>.app", a launcher that starts
# a second Claude desktop instance with its own data folder and Claude Code config.
#
# env: CLAUDE_APP (path to Claude.app, auto-detected by default),
#      APPS_DIR (default ~/Applications), SKIP_REFRESH=1 (don't touch Dock/LaunchServices)
set -euo pipefail

VERSION="1.0.0"

usage() {
  cat <<EOF
claude-twin $VERSION - run a second Claude account side by side on macOS

Usage: setup.sh [options]

  --name NAME    Profile name (default: Work). Letters, digits, spaces, hyphens.
  --hue RADIANS  Icon color shift (default: 3.45 = blue; 2.2 = green, 4.6 = purple)
  --no-icon      Keep the generic launcher icon
  --uninstall    Remove the launcher (data folders are kept)
  --dry-run      Show what would happen, change nothing
  -h, --help     Show this help
  --version      Show the version
EOF
}

die() { echo "Error: $*" >&2; exit 1; }

NAME="Work"
ICON=1
HUE="3.45"
DRY=0
UNINSTALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --name) [ $# -ge 2 ] || die "--name needs a value"; NAME="$2"; shift 2 ;;
    --hue) [ $# -ge 2 ] || die "--hue needs a value"; HUE="$2"; shift 2 ;;
    --no-icon) ICON=0; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --version) echo "claude-twin $VERSION"; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[ "$(uname)" = "Darwin" ] || die "claude-twin only works on macOS."
[[ "$NAME" =~ ^[A-Za-z0-9][A-Za-z0-9\ -]{0,29}$ ]] || die "the name may contain letters, digits, spaces and hyphens (max 30 characters)."
[[ "$HUE" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || die "--hue must be a number (radians)."

SLUG="$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
DATA_DIR_NAME="Claude-$(echo "$NAME" | tr ' ' '-')"
APPS_DIR="${APPS_DIR:-$HOME/Applications}"
LAUNCHER="$APPS_DIR/Claude - $NAME.app"
HERE="$(cd "$(dirname "$0")" && pwd)"

# Only ever replace or remove a launcher that this script created.
is_our_launcher() {
  [ -f "$1/Contents/Resources/Scripts/main.scpt" ] &&
    osadecompile "$1/Contents/Resources/Scripts/main.scpt" 2>/dev/null | grep -q -- '--user-data-dir='
}

if [ "$UNINSTALL" = 1 ]; then
  [ -e "$LAUNCHER" ] || die "no launcher found at $LAUNCHER"
  is_our_launcher "$LAUNCHER" || die "$LAUNCHER was not created by claude-twin; not touching it."
  if [ "$DRY" = 1 ]; then echo "Would remove: $LAUNCHER"; exit 0; fi
  rm -rf "$LAUNCHER"
  echo "Removed $LAUNCHER"
  echo "Kept (delete manually if you no longer need the chats and settings in them):"
  echo "  $HOME/Library/Application Support/$DATA_DIR_NAME"
  echo "  $HOME/.claude-$SLUG"
  exit 0
fi

if [ -n "${CLAUDE_APP:-}" ]; then
  [ -d "$CLAUDE_APP" ] || die "CLAUDE_APP=$CLAUDE_APP does not exist."
else
  for c in "/Applications/Claude.app" "$HOME/Applications/Claude.app"; do
    [ -d "$c" ] && { CLAUDE_APP="$c"; break; }
  done
  [ -n "$CLAUDE_APP" ] || die "Claude.app not found in /Applications or ~/Applications. Install the Claude desktop app first, or set CLAUDE_APP."
fi

if [ -e "$LAUNCHER" ] && ! is_our_launcher "$LAUNCHER"; then
  die "$LAUNCHER already exists and was not created by claude-twin. Choose another --name."
fi

echo "Claude app:      $CLAUDE_APP"
echo "Launcher:        $LAUNCHER"
echo "Desktop data:    $HOME/Library/Application Support/$DATA_DIR_NAME"
echo "Claude Code cfg: $HOME/.claude-$SLUG"
[ "$DRY" = 1 ] && { echo "(dry run, nothing changed)"; exit 0; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# $HOME is left for the shell to expand at launch time, so the launcher stays portable.
# pgrep -a: also match ancestors, in case the launcher is started from inside a Claude session.
cat > "$WORK/main.applescript" <<EOF
-- Created by claude-twin $VERSION
-- Don't start a second instance of this profile if one is already running.
set alreadyRunning to do shell script "pgrep -a -f '[C]laude.app/Contents/MacOS/Claude --user-data-dir=.*/$DATA_DIR_NAME( |\$)' > /dev/null && echo yes || echo no"
if alreadyRunning is "yes" then
	display notification "Claude - $NAME is already running." with title "Claude - $NAME"
else
	-- Separate desktop data folder and separate Claude Code config folder.
	do shell script "open -n --env CLAUDE_CONFIG_DIR=\"\$HOME/.claude-$SLUG\" -a \"$CLAUDE_APP\" --args --user-data-dir=\"\$HOME/Library/Application Support/$DATA_DIR_NAME\" > /dev/null 2>&1 &"
end if
EOF

# Build in the temp folder first, so a failure never leaves a half-made launcher behind.
osacompile -o "$WORK/launcher.app" "$WORK/main.applescript"

make_icon() {
  if ! { command -v swift >/dev/null 2>&1 && swift --version >/dev/null 2>&1; }; then
    echo "Note: swift is not available (install with: xcode-select --install); skipping the icon."
    return 1
  fi
  local icon_file src label s d
  icon_file="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIconFile' "$CLAUDE_APP/Contents/Info.plist")"
  src="$CLAUDE_APP/Contents/Resources/${icon_file%.icns}.icns"
  [ -f "$src" ] || { echo "Note: Claude icon not found; skipping the icon."; return 1; }
  sips -s format png "$src" --out "$WORK/base.png" >/dev/null
  sips -z 1024 1024 "$WORK/base.png" >/dev/null
  label="$(echo "$NAME" | tr '[:lower:]' '[:upper:]')"
  if ! swift "$HERE/make_icon.swift" "$WORK/base.png" "$WORK/icon.png" "$label" "$HUE" >"$WORK/swift.log" 2>&1 ||
    [ ! -f "$WORK/icon.png" ]; then
    echo "Note: icon generation failed; skipping the icon. Details:"
    tail -5 "$WORK/swift.log"
    return 1
  fi
  mkdir "$WORK/icon.iconset"
  for s in 16 32 128 256 512; do
    sips -z "$s" "$s" "$WORK/icon.png" --out "$WORK/icon.iconset/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2)); sips -z "$d" "$d" "$WORK/icon.png" --out "$WORK/icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$WORK/icon.iconset" -o "$WORK/launcher.app/Contents/Resources/applet.icns"
  # Without this key macOS shows the generic script icon from Assets.car instead of applet.icns.
  /usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' "$WORK/launcher.app/Contents/Info.plist" 2>/dev/null || true
  echo "Icon added (badge: $label)."
}
[ "$ICON" = 1 ] && { make_icon || true; }

codesign --force --deep -s - "$WORK/launcher.app" >/dev/null 2>&1
codesign --verify "$WORK/launcher.app"

mkdir -p "$APPS_DIR"
rm -rf "$LAUNCHER"
mv "$WORK/launcher.app" "$LAUNCHER"
touch "$LAUNCHER"
echo "Launcher installed."

if [ "${SKIP_REFRESH:-0}" != 1 ]; then
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$LAUNCHER"
  killall Dock 2>/dev/null || true
fi

cat <<EOF

Done. First login:
  1. Quit the main Claude app (Cmd+Q).
  2. Open "Claude - $NAME" and log in with the other account.
  3. Reopen the main Claude app.
EOF
