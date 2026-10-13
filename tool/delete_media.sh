#!/usr/bin/env bash
# Deletes served keys that no longer correspond to anything content/
# references — tool/media_ledger.dart's `removedKeys`, written to
# build/media-removed-keys.txt. Scoped to the media/ prefix, so this can
# never touch the content/ prefix (the text packs).
#
# Run this AFTER the new content is live (decision K2) — deleting first
# would leave a window where a phone still on the old content points at an
# image that's already gone.
#
# Usage: tool/delete_media.sh [--dry-run]
set -euo pipefail
cd "$(dirname "$0")/.."

LIST=build/media-removed-keys.txt
if [[ ! -s "$LIST" ]] || ! grep -q '[^[:space:]]' "$LIST"; then
  echo "✓ nothing to remove."
  exit 0
fi

rclone delete r2:long-ky-content/media \
  --files-from "$LIST" \
  --s3-no-check-bucket \
  "$@"
echo "✓ removed $(grep -c '[^[:space:]]' "$LIST") file(s) no longer referenced."
