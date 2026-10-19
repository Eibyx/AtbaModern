#!/usr/bin/env bash
set -euo pipefail
export FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true CI=true
ATBA_FLUTTER_DIR="${1:?Pass an absolute writable Flutter SDK directory}"
ATBA_FLUTTER_COMMIT=6a19cca56475dbfba1478ee68d7bd0c2ef891da1
if ! test -d "$ATBA_FLUTTER_DIR"; then
  git clone --depth 1 --branch 3.47.5 --single-branch https://github.com/flutter/flutter.git "$ATBA_FLUTTER_DIR"
fi
test "$(git -C "$ATBA_FLUTTER_DIR" rev-parse HEAD)" = "$ATBA_FLUTTER_COMMIT" || {
  echo 'Unexpected Flutter SDK revision. Existing files were not reset.' >&2
  exit 1
}
"$ATBA_FLUTTER_DIR/bin/flutter" --version
if test -n "${GITHUB_PATH:-}"; then
  printf '%s\n' "$ATBA_FLUTTER_DIR/bin" >> "$GITHUB_PATH"
fi
