#!/usr/bin/env bash
set -e

# --- Guard: confirm the real NUZL source is present (not a demo) ---
if [ ! -f lib/app.dart ] || [ ! -f lib/core/router/app_router.dart ]; then
  echo "=================================================================="
  echo "ERROR: NUZL app code is missing from this repository."
  echo "The 'lib' folder did not upload correctly."
  echo "Upload the complete 'lib' folder (use GitHub Desktop), then redeploy."
  echo "=================================================================="
  exit 1
fi

# --- Download a pinned Flutter SDK and build the web app ---
curl -fsSL -o flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.1-stable.tar.xz
tar xf flutter.tar.xz
export PATH="$PATH:$(pwd)/flutter/bin"
git config --global --add safe.directory "$(pwd)/flutter"
flutter config --enable-web --no-analytics
# generate only the missing web runner files; never overwrites our lib/
flutter create . --platforms=web --project-name nuzl_app
flutter pub get
# SENTRY_DSN is optional — empty define keeps crash reporting dormant.
flutter build web --release --dart-define=API_BASE_URL=/api --dart-define=SENTRY_DSN="${SENTRY_DSN:-}" --dart-define=SENTRY_ENV="${VERCEL_ENV:-production}"
