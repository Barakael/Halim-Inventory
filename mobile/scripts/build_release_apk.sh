#!/usr/bin/env bash
# Build a release APK pointed at a Laravel API.
# Usage:
#   ./scripts/build_release_apk.sh
#   ./scripts/build_release_apk.sh https://api.example.com/api
set -euo pipefail
cd "$(dirname "$0")/.."

API_BASE_URL="${1:-https://haslim.co.tz/api}"
# Normalize: ensure trailing /api path is present when user passes host only
if [[ "$API_BASE_URL" != *"/api" && "$API_BASE_URL" != *"/api/" ]]; then
  API_BASE_URL="${API_BASE_URL%/}/api"
fi

echo "Building release APK with API_BASE_URL=$API_BASE_URL"
flutter pub get
flutter build apk --release \
  --dart-define="API_BASE_URL=$API_BASE_URL"

OUT="build/app/outputs/flutter-apk/app-release.apk"
echo "APK: $(pwd)/$OUT"
ls -lh "$OUT"
