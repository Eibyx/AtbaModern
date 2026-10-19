#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get --enforce-lockfile
for package in torbox_api parse_torrent_title; do
  (cd "packages/$package" && dart pub get)
done
(cd packages/torbox_api && dart run build_runner build)
dart run build_runner build
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --reporter expanded
(cd packages/torbox_api && flutter test test/torbox_api_test.dart --reporter expanded)
(cd packages/parse_torrent_title && dart test --reporter expanded)
echo 'Live TorBox tests are excluded: a real account is not required by CI.'
