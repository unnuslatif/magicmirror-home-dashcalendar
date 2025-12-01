#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/unnusl/magicmirror-home-dashcalendar.git"
TARGET_DIR="${HOME}/magicmirror-home-dashcalendar"

echo "MagicMirror Home DashCalendar - bootstrap installer"

if [[ -d "$TARGET_DIR/.git" ]]; then
  echo "→ Existing repo found at $TARGET_DIR, pulling latest..."
  git -C "$TARGET_DIR" pull --ff-only
else
  echo "→ Cloning repo into $TARGET_DIR..."
  git clone "$REPO_URL" "$TARGET_DIR"
fi

cd "$TARGET_DIR"
chmod +x setup-mirror.sh
./setup-mirror.sh
