#!/usr/bin/env bash
# Uploads only the media build/media-changed-keys.txt lists — the
# incremental counterpart to sync_media.sh's full `rclone sync
# --delete-excluded`. Deliberately `copy`, never `sync`: most served keys
# were never staged locally in incremental mode (see
# gen_media_manifest.dart --only), and `sync --files-from` would read that
# absence as "deleted from source" and remove them from the CDN. Removals
# are handled separately by tool/delete_media.sh, from the ledger's own
# removed-keys list, not by inference.
#
# Usage: tool/sync_media_changed.sh [--dry-run]
set -euo pipefail
cd "$(dirname "$0")/.."

LIST=build/media-changed-keys.txt
if [[ ! -s "$LIST" ]] || ! grep -q '[^[:space:]]' "$LIST"; then
  echo "✓ nothing changed — no media to upload."
  exit 0
fi

rclone copy build/media r2:long-ky-content/media \
  --files-from "$LIST" \
  --header-upload "Cache-Control: public, max-age=31536000, immutable" \
  --s3-no-check-bucket \
  --progress "$@"
echo "✓ uploaded $(grep -c '[^[:space:]]' "$LIST") changed file(s)."
