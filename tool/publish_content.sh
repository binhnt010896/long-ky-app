#!/usr/bin/env bash
# Publish a new content pack (era text/people/periods/media-manifest) to R2.
# Media goes up first, so a pack can never reference an image that isn't
# there yet. The pack itself is content-addressed (versioned + sha256'd) and
# latest.json is the only mutable pointer — it must never be cached, or
# phones would keep serving a stale version.
#
# Usage: tool/publish_content.sh [--dry-run]
set -euo pipefail
cd "$(dirname "$0")/.."

tool/sync_media.sh "$@"
dart run tool/build_content_pack.dart

VERSION=$(python3 -c "import json; print(json.load(open('build/pack/latest.json'))['version'])")

if [[ "${1:-}" == "--dry-run" ]]; then
  echo "→ dry run: would upload build/pack/${VERSION}.json and build/pack/latest.json"
  echo "  (rerun without --dry-run to actually publish)"
  exit 0
fi

# --s3-no-check-bucket: our R2 API token is scoped to this one bucket, with
# no ListBuckets/HeadBucket permission — rclone's default pre-upload bucket
# check reads that as "bucket missing," tries to create it, and that create
# is denied too. The bucket already exists; skip the check.
rclone copyto "build/pack/${VERSION}.json" \
  "r2:long-ky-content/content/packs/${VERSION}.json" \
  --header-upload "Cache-Control: public, max-age=31536000, immutable" \
  --s3-no-check-bucket

rclone copyto "build/pack/latest.json" \
  "r2:long-ky-content/content/latest.json" \
  --header-upload "Cache-Control: no-cache" \
  --s3-no-check-bucket

echo "✓ published content pack ${VERSION}"
echo "  Commit content/content-version.json (and this run's other content changes) now."
