#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
command -v img2webp >/dev/null || { echo 'img2webp (WebP tools) is required.' >&2; exit 1; }
mkdir -p "$repo_dir/images"
for scenario in list tree; do
  frames=("$repo_dir/build/example-demos/$scenario/"*.png)
  # Preserve small UI labels and icons without lossy compression artifacts.
  img2webp -loop 0 -lossless -q 75 -m 4 -d 83 \
    "${frames[@]}" -o "$repo_dir/images/$scenario.webp"
done
