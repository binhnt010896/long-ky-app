#!/usr/bin/env bash
# Publish era media to R2. tool/gen_media_manifest.dart converts every
# referenced source into a served WebP (or copies it as-is) under the
# build/media staging dir; this uploads that staging dir to the bucket's
# media/ prefix. Deletions are scoped to media/, so this can never touch the
# content/ prefix (Phase B's content packs).
# Usage: tool/sync_media.sh [--dry-run]
set -euo pipefail
cd "$(dirname "$0")/.."
dart run tool/gen_media_manifest.dart
# --s3-no-check-bucket: skip rclone's pre-upload bucket-exists check — our
# R2 API token has no ListBuckets/HeadBucket permission, so that check
# always misreads an existing bucket as missing (see publish_content.sh).
rclone sync build/media r2:long-ky-content/media \
  --files-from build/media-files.txt \
  --delete-excluded \
  --header-upload "Cache-Control: public, max-age=31536000, immutable" \
  --s3-no-check-bucket \
  --progress "$@"
