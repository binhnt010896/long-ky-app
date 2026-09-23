#!/usr/bin/env bash
# Publish era media to R2. The manifest decides what ships: only files the
# content JSON references. Remote files outside that list are deleted.
# Usage: tool/sync_media.sh [--dry-run]
set -euo pipefail
cd "$(dirname "$0")/.."
dart run tool/gen_media_manifest.dart
rclone sync content r2:long-ky-content \
  --files-from build/media-files.txt \
  --delete-excluded \
  --header-upload "Cache-Control: public, max-age=31536000, immutable" \
  --progress "$@"
