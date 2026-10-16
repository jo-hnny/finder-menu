#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
swift test --package-path "$ROOT_DIR/Core" --scratch-path "$ROOT_DIR/.build/Core"
swift test --package-path "$ROOT_DIR" --scratch-path "$ROOT_DIR/.build/WindowingTests"
