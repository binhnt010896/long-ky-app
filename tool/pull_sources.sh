#!/usr/bin/env bash
# Pulls original content media from the `long-ky-sources` R2 bucket down into
# content/ — the counterpart to push_sources.sh, for picking up anything
# uploaded elsewhere (the CMS, another contributor, CI) that this Mac
# doesn't have yet.
#
# Copy-only, both directions: never deletes a remote-only file, and never
# deletes a file that exists locally but not remotely (so an image you're
# mid-way through generating locally, not yet pushed, survives a pull).
#
# Usage: tool/pull_sources.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Pulling content media from long-ky-sources…"
rclone copy r2:long-ky-sources content/ --s3-no-check-bucket --progress "$@"
echo "✓ pulled."
