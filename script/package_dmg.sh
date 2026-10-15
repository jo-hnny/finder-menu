#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/Packaging"
APP_BUNDLE="$BUILD_DIR/Build/Products/Release/Finder Menu.app"
# CI passes MARKETING_VERSION / CURRENT_PROJECT_VERSION; local builds use Config/Base.xcconfig.
VERSION="${MARKETING_VERSION:-$(awk -F' = ' '$1 == "MARKETING_VERSION" { print $2 }' "$ROOT_DIR/Config/Base.xcconfig")}"
BUILD_NUMBER="${CURRENT_PROJECT_VERSION:-$(awk -F' = ' '$1 == "CURRENT_PROJECT_VERSION" { print $2 }' "$ROOT_DIR/Config/Base.xcconfig")}"
OUTPUT="$ROOT_DIR/dist/Finder-Menu-$VERSION-arm64.dmg"

mkdir -p "$BUILD_DIR" "$ROOT_DIR/dist"
STAGING="$(mktemp -d "$BUILD_DIR/dmg.XXXXXX")"
MOUNT_POINT="$STAGING/mount"
cleanup() {
  if mount | grep -Fq " on $MOUNT_POINT ("; then
    hdiutil detach "$MOUNT_POINT" || return
  fi
  rm -rf "$STAGING"
}
trap cleanup EXIT

PUBLIC_KEY="${SPARKLE_PUBLIC_ED_KEY-$(sed -n 's/^SPARKLE_PUBLIC_ED_KEY = *//p' "$ROOT_DIR/Config/Base.xcconfig")}"

xcodebuild -quiet -project "$ROOT_DIR/FinderMenu.xcodeproj" \
  -scheme FinderMenu -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$BUILD_DIR" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  SPARKLE_PUBLIC_ED_KEY="$PUBLIC_KEY" build

codesign --verify --deep --strict --all-architectures "$APP_BUNDLE"
for BINARY in \
  "$APP_BUNDLE/Contents/MacOS/FinderMenu" \
  "$APP_BUNDLE/Contents/PlugIns/FinderMenuExtension.appex/Contents/MacOS/FinderMenuExtension" \
  "$APP_BUNDLE/Contents/Helpers/FinderMenuOpener.app/Contents/MacOS/FinderMenuOpener"; do
  [[ "$(/usr/bin/lipo -archs "$BINARY")" == arm64 ]]
done
for PLIST in \
  "$APP_BUNDLE/Contents/Info.plist" \
  "$APP_BUNDLE/Contents/PlugIns/FinderMenuExtension.appex/Contents/Info.plist" \
  "$APP_BUNDLE/Contents/Helpers/FinderMenuOpener.app/Contents/Info.plist"; do
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")" == "$VERSION" ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")" == "$BUILD_NUMBER" ]]
done

mkdir "$STAGING/content" "$MOUNT_POINT"
ditto "$APP_BUNDLE" "$STAGING/content/Finder Menu.app"
ln -s /Applications "$STAGING/content/Applications"
cat > "$STAGING/content/安装说明.txt" <<'EOF'
Finder Menu

系统要求：macOS 14 或更新版本，仅支持 Apple Silicon（M 系列芯片）。

1. 退出正在运行的 Finder Menu，将 Finder Menu.app 拖入 Applications。
2. 从 Applications 打开 Finder Menu，点击窗口底部「管理…」，在系统设置中启用 Finder 扩展。
3. 添加应用、调整菜单顺序和显示范围。配置自动保存，退出主应用后右键菜单仍可使用。
4. 安装完成后弹出此磁盘映像。

此包使用本地 ad-hoc 签名，未进行 Apple 公证。用于本地原型安装与测试。
EOF

hdiutil create -volname 'Finder Menu' -srcfolder "$STAGING/content" \
  -fs HFS+ -format UDZO -ov "$STAGING/Finder Menu.dmg"
hdiutil verify "$STAGING/Finder Menu.dmg"
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT_POINT" "$STAGING/Finder Menu.dmg"
codesign --verify --deep --strict --all-architectures "$MOUNT_POINT/Finder Menu.app"
[[ "$(readlink "$MOUNT_POINT/Applications")" == /Applications ]]
[[ -f "$MOUNT_POINT/安装说明.txt" ]]
hdiutil detach "$MOUNT_POINT"
mv "$STAGING/Finder Menu.dmg" "$OUTPUT"
(cd "$ROOT_DIR/dist" && shasum -a 256 "$(basename "$OUTPUT")") > "$OUTPUT.sha256"
echo "Packaged: $OUTPUT"
