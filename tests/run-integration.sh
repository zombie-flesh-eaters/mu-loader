#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

PROJECT_DIR="${TMP_DIR}/wp-project"
mkdir -p "${PROJECT_DIR}/wp-content/mu-plugins" "${PROJECT_DIR}/web/app/mu-plugins"

cat > "${PROJECT_DIR}/composer.json" <<JSON
{
  "name": "test/wp-project",
  "type": "project",
  "repositories": {
    "packagist.org": false,
    "local": {
      "type": "path",
      "url": "${ROOT_DIR}",
      "options": {
        "symlink": true,
        "versions": {
          "zombie-flesh-eaters/mu-loader": "0.0.0"
        }
      }
    }
  },
  "require": {
    "zombie-flesh-eaters/mu-loader": "0.0.0"
  },
  "config": {
    "vendor-dir": "wp-content/vendor",
    "allow-plugins": {
      "zombie-flesh-eaters/mu-loader": true
    }
  },
  "extra": {
    "mu-loader": {
      "paths": [
        "wp-content/mu-plugins",
        "web/app/mu-plugins"
      ],
      "output": "wp-content/mu-plugins/000-mu-loader.php",
      "exclude": [
        "wp-content/mu-plugins/skip-me.php"
      ]
    }
  }
}
JSON

cat > "${PROJECT_DIR}/wp-content/mu-plugins/zzz.php" <<'PHP'
<?php
PHP

cat > "${PROJECT_DIR}/wp-content/mu-plugins/skip-me.php" <<'PHP'
<?php
PHP

cat > "${PROJECT_DIR}/web/app/mu-plugins/alpha.php" <<'PHP'
<?php
PHP

cd "${PROJECT_DIR}"
composer install --no-interaction --no-ansi --no-progress >/dev/null

OUTPUT_FILE="${PROJECT_DIR}/wp-content/mu-plugins/000-mu-loader.php"
if [[ ! -f "${OUTPUT_FILE}" ]]; then
  echo "FAIL: output file was not generated: ${OUTPUT_FILE}"
  exit 1
fi

if grep -Fq "skip-me.php" "${OUTPUT_FILE}"; then
  echo "FAIL: excluded file was included in generated loader"
  exit 1
fi

EXPECTED_FIRST="require_once __DIR__ . '/../../web/app/mu-plugins/alpha.php';"
EXPECTED_SECOND="require_once __DIR__ . '/zzz.php';"

FIRST_REQUIRE="$(grep -E "^require_once " "${OUTPUT_FILE}" | sed -n '1p')"
SECOND_REQUIRE="$(grep -E "^require_once " "${OUTPUT_FILE}" | sed -n '2p')"

if [[ "${FIRST_REQUIRE}" != "${EXPECTED_FIRST}" ]]; then
  echo "FAIL: first require mismatch"
  echo "Expected: ${EXPECTED_FIRST}"
  echo "Actual:   ${FIRST_REQUIRE}"
  exit 1
fi

if [[ "${SECOND_REQUIRE}" != "${EXPECTED_SECOND}" ]]; then
  echo "FAIL: second require mismatch"
  echo "Expected: ${EXPECTED_SECOND}"
  echo "Actual:   ${SECOND_REQUIRE}"
  exit 1
fi

echo "PASS: integration test succeeded"
