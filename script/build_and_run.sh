#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ALLOW_RELOAD="${2:-}"
usage() {
  echo "usage: $0 [run|--build-only|--verify|--debug|--logs|--telemetry] [--allow-extension-reload]" >&2
  exit 2
}
case "$MODE" in
  run|--build-only|--verify|--debug|--logs|--telemetry) ;;
  *) usage ;;
esac
if [[ $# -gt 2 || ( -n "$ALLOW_RELOAD" && "$ALLOW_RELOAD" != --allow-extension-reload ) ||
      ( "$MODE" == --build-only && -n "$ALLOW_RELOAD" ) ]]; then usage; fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/.build/DerivedData/Build/Products/Debug/Finder Menu.app"
EXTENSION_BUNDLE="$APP_BUNDLE/Contents/PlugIns/FinderMenuExtension.appex"
EXTENSION_ID="dev.jojo.FinderMenu.Extension"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
PRESERVED_EXTENSION=""

# Xcode registers macOS app products during build, including --build-only.
# Snapshot the existing copy before building and restore it even on failure.
if [[ "$ALLOW_RELOAD" != --allow-extension-reload ]]; then
  REGISTRATION="$(/usr/bin/pluginkit -m -v -i "$EXTENSION_ID")"
  SELECTED_EXTENSION="$(printf '%s\n' "$REGISTRATION" | /usr/bin/awk -F '\t' '/\.appex$/ {print $NF; exit}')"
  if [[ -n "$SELECTED_EXTENSION" && "$SELECTED_EXTENSION" != "$EXTENSION_BUNDLE" ]]; then
    PRESERVED_EXTENSION="$SELECTED_EXTENSION"
  else
    for installed_app in "/Applications/Finder Menu.app" "$HOME/Applications/Finder Menu.app"; do
      if [[ -d "$installed_app/Contents/PlugIns/FinderMenuExtension.appex" ]]; then
        PRESERVED_EXTENSION="$installed_app/Contents/PlugIns/FinderMenuExtension.appex"
        break
      fi
    done
  fi
fi

restore_extension() {
  local build_status=$?
  local restore_status=0
  local registrations
  trap - EXIT
  registrations="$(/usr/bin/pluginkit -m -A -D -v -i "$EXTENSION_ID")" || restore_status=$?
  if [[ "$registrations" == *"$EXTENSION_BUNDLE"* ]]; then
    /usr/bin/pluginkit -r "$EXTENSION_BUNDLE" || restore_status=$?
  fi
  /usr/bin/pluginkit -a "$PRESERVED_EXTENSION" || restore_status=$?
  if [[ "$REGISTRATION" == +* ]]; then
    /usr/bin/pluginkit -e ignore -i "$EXTENSION_ID" || restore_status=$?
    /usr/bin/pluginkit -e use -i "$EXTENSION_ID" || restore_status=$?
  fi
  if [[ "$restore_status" -ne 0 ]]; then
    echo "Could not fully restore extension: $PRESERVED_EXTENSION" >&2
    exit "$restore_status"
  fi
  echo "Restored extension: $PRESERVED_EXTENSION"
  exit "$build_status"
}
if [[ -n "$PRESERVED_EXTENSION" ]]; then
  trap restore_extension EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
fi

xcodebuild -quiet -project "$ROOT_DIR/FinderMenu.xcodeproj" \
  -scheme FinderMenu -configuration Debug -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath "$ROOT_DIR/.build/DerivedData" build

codesign --verify --deep --strict "$APP_BUNDLE"
echo "Built: $APP_BUNDLE"
if [[ "$MODE" == --build-only ]]; then exit 0; fi

# Launching the development app also registers its embedded extension. Preserve
# installed/registered copies unless the caller explicitly opts into a reload.
if [[ -n "$PRESERVED_EXTENSION" ]]; then
  echo "Preserving the existing Finder Menu copy; development app was not launched."
  echo "To explicitly run the development copy: $0 $MODE --allow-extension-reload"
  exit 0
fi

pkill -x FinderMenu >/dev/null 2>&1 || true

# Register this exact development build; enabling it remains a separate system setting.
"$LSREGISTER" -f "$APP_BUNDLE"
/usr/bin/pluginkit -a "$EXTENSION_BUNDLE"
# Reload only if the user has already enabled this extension. Killing its process
# alone can leave Finder without menus until the next enable cycle.
if /usr/bin/pluginkit -m -i dev.jojo.FinderMenu.Extension | /usr/bin/grep -q '^+'; then
  /usr/bin/pluginkit -e ignore -i dev.jojo.FinderMenu.Extension
  /usr/bin/pluginkit -e use -i dev.jojo.FinderMenu.Extension
fi

if [[ "$MODE" == --debug ]]; then
  exec lldb -- "$APP_BUNDLE/Contents/MacOS/FinderMenu"
fi

/usr/bin/open "$APP_BUNDLE"
case "$MODE" in
  --verify)
    sleep 1
    pgrep -x FinderMenu
    ;;
  --logs|--telemetry)
    exec /usr/bin/log stream --level info --style compact \
      --predicate 'subsystem == "dev.jojo.FinderMenu"'
    ;;
esac
