#!/usr/bin/env bash
# Publish the Vietnamese narration clips to R2 under audio/vi/, then the
# manifest the app reads to know which clips exist. Clips go first so the
# manifest can never list a clip that isn't there yet; the manifest is the only
# mutable object and must never be cached.
# Usage: tool/publish_narration.sh [--dry-run]
set -euo pipefail
cd "$(dirname "$0")/.."
node tool/narration_jobs.mjs >/dev/null
node tool/narration_manifest.mjs
# Only the clips the manifest lists (a clip on disk with stale text is not
# published until it's regenerated).
python3 - <<'PY'
import json
m = json.load(open('build/audio/manifest.json'))['clips']
open('build/audio/files.txt', 'w').write(''.join(f'{k}.mp3\n' for k in sorted(m)))
PY
# --s3-no-check-bucket: see publish_content.sh (token has no HeadBucket).
rclone copy content/audio/vi r2:long-ky-content/audio/vi \
  --files-from build/audio/files.txt \
  --header-upload "Cache-Control: public, max-age=31536000, immutable" \
  --header-upload "Content-Type: audio/mpeg" \
  --s3-no-check-bucket --progress "$@"
if [[ "${1:-}" == "--dry-run" ]]; then
  echo "→ dry run: manifest not uploaded"; exit 0
fi
rclone copyto build/audio/manifest.json r2:long-ky-content/audio/manifest.json \
  --header-upload "Cache-Control: no-cache" \
  --header-upload "Content-Type: application/json" \
  --s3-no-check-bucket
echo "✓ published $(wc -l < build/audio/files.txt | tr -d ' ') narration clips + manifest"
