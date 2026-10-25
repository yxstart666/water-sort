#!/usr/bin/env bash
set -euo pipefail
D="$(cd "$(dirname "$0")/.." && pwd)"
node "$D/source/full_pour_player.js"
ffmpeg -y -hide_banner -loglevel error -framerate 30 -i "$D/qa/frames/frame_%03d.png" -c:v libx264 -pix_fmt yuv420p -crf 17 "$D/qa/full_two_bottle_pour.mp4"
