#!/usr/bin/env bash
# Rebuilds media/teaser/laundry_1-3.mp4 and drawing_1-3.mp4
# Run from anywhere:  bash media/teaser/build_teasers.sh

set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
LAUNDRY="$REPO/media/results/laundry_folding"
DRAW="$REPO/media/results/drawanything_real/unseen_rollout"
OUT="$REPO/media/teaser"

# ── LAUNDRY TEASERS ─────────────────────────────────────────────────────────
# Output: 1920×684  (two 960×684 panels hstacked)
#
# BPP rollout source: laundry_folding/bpp/<task>.mp4  (1440×720)
#   Take first 960px wide and remove 5% from bottom for fold_up and left_arm: crop=960:684:0:0
#   Take first 960px wide and remove 5% from TOP    for right_arm:             crop=960:684:0:36
#
# Prompt source: laundry_folding/prompt/<task>.mp4  (1536×864)
#   Target AR = 960/684 = 1.4035  →  keep 1213px wide out of 1536px
#   Total horizontal cut: 1536−1213 = 323px, split per task:
#     fold_up  : 2:1 left:right  → x=108  (108px from left, 215px from right)
#     left_arm : 2:1 left:right  → x=108
#     right_arm: 1:2 left:right  → x=215  (215px from left, 108px from right)
#   After crop 1213×864, scale to 684h → 960×684

echo "=== Building laundry teasers ==="

# laundry_1: fold_up
ffmpeg -y \
  -i "$LAUNDRY/prompt/fold_up.mp4" \
  -i "$LAUNDRY/bpp/fold_up.mp4" \
  -filter_complex "[0:v]crop=1213:864:108:0,scale=-1:684[l];[1:v]crop=960:684:0:0[r];[l][r]hstack=inputs=2[v]" \
  -map "[v]" -c:v libx264 -crf 18 -preset fast \
  "$OUT/laundry_1.mp4"

# laundry_2: left_arm
ffmpeg -y \
  -i "$LAUNDRY/prompt/left_arm.mp4" \
  -i "$LAUNDRY/bpp/left_arm.mp4" \
  -filter_complex "[0:v]crop=1213:864:108:0,scale=-1:684[l];[1:v]crop=960:684:0:0[r];[l][r]hstack=inputs=2[v]" \
  -map "[v]" -c:v libx264 -crf 18 -preset fast \
  "$OUT/laundry_2.mp4"

# laundry_3: right_arm  (rollout crops from TOP, prompt x offset flipped to 1:2)
ffmpeg -y \
  -i "$LAUNDRY/prompt/right_arm.mp4" \
  -i "$LAUNDRY/bpp/right_arm.mp4" \
  -filter_complex "[0:v]crop=1213:864:215:0,scale=-1:684[l];[1:v]crop=960:684:0:36[r];[l][r]hstack=inputs=2[v]" \
  -map "[v]" -c:v libx264 -crf 18 -preset fast \
  "$OUT/laundry_3.mp4"

# ── DRAWING TEASERS ──────────────────────────────────────────────────────────
# Output: 2304×720  (two 1152×720 panels hstacked)
#
# Source: drawanything_real/unseen_rollout/{prompt,bpp}/<task>.mp4  (1920×1080)
# Per panel: crop center 90% horizontally (5% off left, 5% off right)
#   x = 1920×0.05 = 96px,  width = 1920×0.90 = 1728px
#   Then scale to 720h → 1152×720

echo "=== Building drawing teasers ==="

for task_num in "star:1" "8:2" "B:3"; do
  task="${task_num%%:*}"
  num="${task_num##*:}"
  ffmpeg -y \
    -i "$DRAW/prompt/${task}.mp4" \
    -i "$DRAW/bpp/${task}.mp4" \
    -filter_complex "[0:v]crop=iw*0.90:ih:iw*0.05:0,scale=-1:720[l];[1:v]crop=iw*0.90:ih:iw*0.05:0,scale=-1:720[r];[l][r]hstack=inputs=2[v]" \
    -map "[v]" -c:v libx264 -crf 18 -preset fast \
    "$OUT/drawing_${num}.mp4"
done

echo "=== Concatenating ==="

printf "file '%s/laundry_1.mp4'\nfile '%s/laundry_2.mp4'\nfile '%s/laundry_3.mp4'\n" "$OUT" "$OUT" "$OUT" > "$OUT/concat_laundry.txt"
ffmpeg -y -f concat -safe 0 -i "$OUT/concat_laundry.txt" -c copy "$OUT/laundry_teaser.mp4"
rm "$OUT/concat_laundry.txt"

printf "file '%s/drawing_1.mp4'\nfile '%s/drawing_2.mp4'\nfile '%s/drawing_3.mp4'\n" "$OUT" "$OUT" "$OUT" > "$OUT/concat_drawing.txt"
ffmpeg -y -f concat -safe 0 -i "$OUT/concat_drawing.txt" -c copy "$OUT/drawing_teaser.mp4"
rm "$OUT/concat_drawing.txt"

echo "=== Done ==="
echo "laundry_teaser: $(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,duration -of csv=p=0 "$OUT/laundry_teaser.mp4")"
echo "drawing_teaser: $(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,duration -of csv=p=0 "$OUT/drawing_teaser.mp4")"
