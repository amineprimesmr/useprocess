#!/usr/bin/env bash
# Compress bundled iOS media: lymph/onboarding MP4 + Assets.xcassets PNGs.
# Originals are backed up under content/app-media/source/ (gitignored).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LYMPH_SRC="$ROOT/useprocess/Resources/LymphCircuit"
ONBOARDING_SRC="$ROOT/useprocess/Resources/Onboarding"
BACKUP_LYMPH="$ROOT/content/app-media/source/LymphCircuit"
BACKUP_ONBOARDING="$ROOT/content/app-media/source/Onboarding"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required (brew install ffmpeg)" >&2
  exit 1
fi

compress_video() {
  local input="$1"
  local backup_dir="$2"
  local base
  base="$(basename "$input")"
  local name="${base%.mp4}"
  local tmp="${input}.compressed.tmp.mp4"

  mkdir -p "$backup_dir"
  if [[ ! -f "$backup_dir/$base" ]]; then
    echo "  backup -> content/app-media/source/$(basename "$backup_dir")/$base"
    cp -p "$input" "$backup_dir/$base"
  fi

  echo "  compress $base"
  ffmpeg -y -loglevel error -i "$input" \
    -an \
    -c:v libx265 -tag:v hvc1 \
    -crf 30 -preset faster \
    -vf "scale='min(720,iw)':-2:flags=lanczos" \
    -movflags +faststart \
    "$tmp"

  mv "$tmp" "$input"
  ls -lh "$input" "$backup_dir/$base" | awk '{print "    " $0}'
}

echo "== Lymph circuit videos =="
for video in "$LYMPH_SRC"/lymph_*.mp4; do
  [[ -f "$video" ]] || continue
  compress_video "$video" "$BACKUP_LYMPH"
done

echo ""
echo "== Onboarding videos =="
for video in "$ONBOARDING_SRC"/*.mp4; do
  [[ -f "$video" ]] || continue
  compress_video "$video" "$BACKUP_ONBOARDING"
done

echo ""
echo "== PNG assets =="
python3 "$ROOT/scripts/compress_app_pngs.py"

echo ""
echo "== Summary =="
du -sh "$ROOT/useprocess/Resources" "$ROOT/useprocess/Assets.xcassets" "$ROOT/useprocess" 2>/dev/null || true
echo "Done. Originals preserved in content/app-media/source/"
