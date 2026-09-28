#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter SDK غير موجود في PATH.' >&2
  exit 1
fi

if [ ! -f pubspec.yaml ]; then
  flutter create --platforms=android,ios .
fi

echo 'تم إنشاء/تحديث هيكل Flutter. نفّذ الآن: flutter pub get && flutter run'
