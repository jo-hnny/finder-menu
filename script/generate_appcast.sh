#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPARKLE_BIN_DIR="${SPARKLE_BIN_DIR:-$ROOT_DIR/.build/Packaging/SourcePackages/artifacts/sparkle/Sparkle/bin}"
: "${SPARKLE_PRIVATE_ED_KEY:?Set the Sparkle private key; never commit it.}"
: "${GITHUB_REPOSITORY:?Set the GitHub owner/repository for the download URL.}"
: "${VERSION:?Set the release version.}"
: "${BUILD_NUMBER:?Set the release build number.}"
if [[ $# -ne 1 || ! -f "$1" ]]; then
  echo "usage: $0 <verified-release.dmg>" >&2
  exit 2
fi

# Work in a fresh directory so a previous build cannot enter the feed.
STAGING="$(mktemp -d "$ROOT_DIR/.build/appcast.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
cp "$1" "$STAGING/"
DOWNLOAD_PREFIX="https://github.com/$GITHUB_REPOSITORY/releases/download/v$VERSION/"
printf '%s\n' "$SPARKLE_PRIVATE_ED_KEY" | "$SPARKLE_BIN_DIR/generate_appcast" \
  --ed-key-file - --maximum-deltas 0 --download-url-prefix "$DOWNLOAD_PREFIX" \
  "$STAGING"

# generate_appcast can emit an unsigned item when the signing key does not match.
# Fail before publishing if the archive is unsigned or describes another build.
python3 - "$STAGING/appcast.xml" "$1" "$DOWNLOAD_PREFIX" "$VERSION" "$BUILD_NUMBER" <<'PY'
import base64
import pathlib
import sys
import xml.etree.ElementTree as ET

feed, archive, prefix, version, build = sys.argv[1:]
ns = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
items = ET.parse(feed).findall("./channel/item")
assert len(items) == 1, "Expected exactly one update"
item = items[0]
enclosure = item.find("enclosure")
assert enclosure is not None, "Missing update archive"
signature = enclosure.get(f"{{{ns['sparkle']}}}edSignature", "")
assert len(base64.b64decode(signature, validate=True)) == 64, "Missing Ed25519 signature"
assert item.findtext("sparkle:version", namespaces=ns) == build, "Build number mismatch"
assert item.findtext("sparkle:shortVersionString", namespaces=ns) == version, "Version mismatch"
assert enclosure.get("url") == prefix + pathlib.Path(archive).name, "Download URL mismatch"
assert enclosure.get("length") == str(pathlib.Path(archive).stat().st_size), "Archive size mismatch"
PY

cp "$STAGING/appcast.xml" "$(dirname "$1")/appcast.xml"
echo "Generated signed appcast: $(dirname "$1")/appcast.xml"
