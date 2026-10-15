#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT_DIR/.build/Tests"
xcrun swiftc -module-cache-path "$ROOT_DIR/.build/Tests/ModuleCache" \
  "$ROOT_DIR/Shared/MenuConfiguration.swift" "$ROOT_DIR/Tests/main.swift" \
  -o "$ROOT_DIR/.build/Tests/ConfigurationTests"
"$ROOT_DIR/.build/Tests/ConfigurationTests"
