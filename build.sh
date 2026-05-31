#!/usr/bin/env bash
set -e
curl -fsSL -o flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz
tar xf flutter.tar.xz
export PATH="$PATH:$(pwd)/flutter/bin"
git config --global --add safe.directory "$(pwd)/flutter"
flutter config --enable-web --no-analytics
flutter create . --platforms=web --project-name nuzl_app
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=/api
