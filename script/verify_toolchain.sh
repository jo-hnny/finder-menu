#!/usr/bin/env bash
set -euo pipefail

# Match the local toolchain used to validate the native SwiftUI appearance.
XCODE_VERSION="$(xcodebuild -version)"
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
SDK_BUILD="$(xcrun --sdk macosx --show-sdk-build-version)"
printf '%s\nmacOS SDK %s (%s)\n' "$XCODE_VERSION" "$SDK_VERSION" "$SDK_BUILD"

if [[ "$XCODE_VERSION" != $'Xcode 27.0\nBuild version 27A266a' ]]; then
  echo 'Expected Xcode 27.0 (27A266a). Select the matching Xcode with DEVELOPER_DIR.' >&2
  exit 1
fi
if [[ "$SDK_VERSION" != 27.0 || "$SDK_BUILD" != 26A425 ]]; then
  echo 'Expected macOS SDK 27.0 (26A425). Refusing to build with a different SDK.' >&2
  exit 1
fi
