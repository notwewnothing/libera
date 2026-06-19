#!/usr/bin/env bash
# Generates lib/common/secrets.dart (gitignored) for CI builds.
# Uses the TMDB_API_KEY env/secret if set, otherwise the embedded default key
# (which already ships inside every built artifact, so it is not truly secret).
set -euo pipefail

KEY="${TMDB_API_KEY:-}"
if [ -z "$KEY" ]; then
  KEY="a2759cd2381bc4436c8e943dab9c36f6"
fi

mkdir -p lib/common
printf 'const apikey = "%s";\n' "$KEY" > lib/common/secrets.dart
echo "Wrote lib/common/secrets.dart (key length: ${#KEY})"
