#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
case "$MODE" in
  run|--build-only|--verify|--debug|--logs|--telemetry) ;;
  *) echo "usage: $0 [--build-only|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/.build/DerivedData/Build/Products/Debug/Finder Menu.app"

if [[ "$MODE" != --build-only ]]; then
  pkill -x FinderMenu >/dev/null 2>&1 || true
fi

xcodebuild -quiet -project "$ROOT_DIR/FinderMenu.xcodeproj" \
  -scheme FinderMenu -configuration Debug -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath "$ROOT_DIR/.build/DerivedData" build

codesign --verify --deep --strict "$APP_BUNDLE"
echo "Built: $APP_BUNDLE"
if [[ "$MODE" == --build-only ]]; then exit 0; fi

# Register this exact development build; enabling it remains a separate system setting.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_BUNDLE"
/usr/bin/pluginkit -a "$APP_BUNDLE/Contents/PlugIns/FinderMenuExtension.appex"
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
