#!/usr/bin/env bash
# Builds per-task, per-side teaser clips (no hstack/concat) into media/teaser/tmp/
# Naming: <task>_human.mp4 (prompt side) and <task>_robot.mp4 (bpp side)
# These are intermediate outputs (compressed later), so native resolution is
# kept everywhere and clips that need no crop are stream-copied untouched.
# Run from anywhere:  bash scripts/build_teasers_split.sh

set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
LAUNDRY="$REPO/media/results/laundry_folding"
DRAW="$REPO/media/results/drawanything_real/unseen_rollout"
OUT="$REPO/media/teaser/tmp"

mkdir -p "$OUT"

# ── LAUNDRY TEASERS ─────────────────────────────────────────────────────────
# Human/prompt source: 1536x864 — already 16:9, so no crop, stream-copied as-is.
# Robot/bpp source: 1440x720. The wrist-cam view lives in the rightmost
# 480px, so width is capped at the first 960px (x=0, same as the original
# build_teasers.sh convention) to exclude it entirely. At width=960, hitting
# 16:9 requires height=540 (960*9/16), i.e. an additional 180px cut off the
# height:
#   fold_up   : 60px off top, 120px off bottom -> crop=960:540:0:60
#   left_arm  : cut 180px off the bottom (original bias)        -> crop=960:540:0:0
#   right_arm : cut 180px off the top (original bias)           -> crop=960:540:0:180
# This is the only clip that must be re-encoded (cropping requires
# decode+filter+encode), so it uses crf 0 (mathematically lossless H.264) —
# the crop removes pixels, but nothing else is degraded.

echo "=== Building laundry teaser clips ==="

ffmpeg -y -i "$LAUNDRY/prompt/fold_up.mp4" -c copy "$OUT/fold_up_human.mp4"
ffmpeg -y -i "$LAUNDRY/bpp/fold_up.mp4" \
  -filter_complex "[0:v]crop=960:540:0:60[v]" \
  -map "[v]" -c:v libx264 -crf 0 -preset veryslow "$OUT/fold_up_robot.mp4"

ffmpeg -y -i "$LAUNDRY/prompt/left_arm.mp4" -c copy "$OUT/left_arm_human.mp4"
ffmpeg -y -i "$LAUNDRY/bpp/left_arm.mp4" \
  -filter_complex "[0:v]crop=960:540:0:0[v]" \
  -map "[v]" -c:v libx264 -crf 0 -preset veryslow "$OUT/left_arm_robot.mp4"

ffmpeg -y -i "$LAUNDRY/prompt/right_arm.mp4" -c copy "$OUT/right_arm_human.mp4"
ffmpeg -y -i "$LAUNDRY/bpp/right_arm.mp4" \
  -filter_complex "[0:v]crop=960:540:0:180[v]" \
  -map "[v]" -c:v libx264 -crf 0 -preset veryslow "$OUT/right_arm_robot.mp4"

# ── DRAWING TEASERS ──────────────────────────────────────────────────────────
# Source: 1920x1080 — already 16:9 for both sides, no crop needed, stream-copied.

echo "=== Building drawing teaser clips ==="

for task in star 8 B; do
  ffmpeg -y -i "$DRAW/prompt/${task}.mp4" -c copy "$OUT/${task}_human.mp4"
  ffmpeg -y -i "$DRAW/bpp/${task}.mp4" -c copy "$OUT/${task}_robot.mp4"
done

echo "=== Done ==="
echo "Output written to: $OUT"
ls "$OUT"
