#!/usr/bin/env bash
# Pushes original content media — the images/video under content/ that never
# leave this Mac today (content/**/*.png etc. are gitignored; see
# .gitignore) — up to the private `long-ky-sources` R2 bucket. That bucket is
# the single source of truth originals now sync from: a hosted CMS has
# nowhere else to put a new image's original, and this Mac being the only
# copy of 3.4 GB of art was a backup risk worth fixing on its own.
#
# Copy-only — never deletes anything on the remote. That's what keeps the Mac
# and CI/the CMS from ever racing and deleting each other's uploads: this can
# only ever add or update, never remove.
#
# Usage:
#   tool/push_sources.sh            # push anything new/changed
#   tool/push_sources.sh --check    # exit 1 if anything local is unpushed,
#                                    # without uploading — publish_content.sh
#                                    # runs this before a local publish, so a
#                                    # forgotten push can never cause the next
#                                    # `tool/sync_media.sh --delete-excluded`
#                                    # to delete a served image whose original
#                                    # only exists on this Mac.
set -euo pipefail
cd "$(dirname "$0")/.."

# Only content/'s media — never its JSON, docs, or stray .DS_Store files.
EXCLUDES=(--exclude "*.json" --exclude "*.md" --exclude ".DS_Store" --exclude "**/.DS_Store")

if [[ "${1:-}" == "--check" ]]; then
  echo "Checking for content media not yet pushed to long-ky-sources…"
  if rclone check content/ r2:long-ky-sources --one-way "${EXCLUDES[@]}" \
    --s3-no-check-bucket; then
    echo "✓ everything is pushed."
    exit 0
  else
    echo "✗ some local media is not yet in long-ky-sources."
    echo "  Run: tool/push_sources.sh"
    exit 1
  fi
fi

echo "Pushing content media to long-ky-sources…"
# --s3-no-check-bucket: our R2 API token has no ListBuckets/HeadBucket
# permission — rclone's default pre-upload bucket check misreads an existing
# bucket as missing and tries (and fails) to create it (see publish_content.sh).
#
# --update: skip a file if the remote copy is newer than the local one.
# Since the CMS (Cycle H) can now replace a media original directly in
# long-ky-sources, a plain `copy` from this Mac could silently put a stale
# local file back over a newer CMS upload — --update is what stops that.
# Always `pull_sources.sh` before a push if you're not sure the Mac is
# current.
rclone copy content/ r2:long-ky-sources "${EXCLUDES[@]}" \
  --s3-no-check-bucket --update --progress "$@"
echo "✓ pushed."
