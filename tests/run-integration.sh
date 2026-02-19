#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

PROJECT_DIR="${TMP_DIR}/wp-project"
mkdir -p \
  "${PROJECT_DIR}/wp-content/mu-plugins/security-headers/inc" \
  "${PROJECT_DIR}/web/app/mu-plugins/sample-plugin/includes"

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

cat > "${PROJECT_DIR}/wp-content/mu-plugins/security-headers/security-headers.php" <<'PHP'
<?php
PHP

cat > "${PROJECT_DIR}/wp-content/mu-plugins/security-headers/inc/internal.php" <<'PHP'
<?php
PHP

cat > "${PROJECT_DIR}/web/app/mu-plugins/sample-plugin/sample-plugin.php" <<'PHP'
<?php
PHP

cat > "${PROJECT_DIR}/web/app/mu-plugins/sample-plugin/includes/runtime.php" <<'PHP'
<?php
PHP

cd "${PROJECT_DIR}"
composer install --no-interaction --no-ansi --no-progress >/dev/null

OUTPUT_FILE="${PROJECT_DIR}/wp-content/mu-plugins/000-mu-loader.php"
if [[ ! -f "${OUTPUT_FILE}" ]]; then
  echo "FAIL: output file was not generated: ${OUTPUT_FILE}"
  exit 1
fi

if grep -Fq "internal.php" "${OUTPUT_FILE}" || grep -Fq "runtime.php" "${OUTPUT_FILE}"; then
  echo "FAIL: non-entry files were included in generated loader"
  exit 1
fi

EXPECTED_A="require_once __DIR__ . '/security-headers/security-headers.php';"
EXPECTED_B="require_once __DIR__ . '/../../web/app/mu-plugins/sample-plugin/sample-plugin.php';"

REQUIRE_COUNT="$(grep -Ec "^require_once " "${OUTPUT_FILE}")"
if [[ "${REQUIRE_COUNT}" != "2" ]]; then
  echo "FAIL: expected exactly 2 require_once lines, got ${REQUIRE_COUNT}"
  exit 1
fi

if ! grep -Fq "${EXPECTED_A}" "${OUTPUT_FILE}"; then
  echo "FAIL: missing expected entry file require"
  echo "Missing: ${EXPECTED_A}"
  exit 1
fi

if ! grep -Fq "${EXPECTED_B}" "${OUTPUT_FILE}"; then
  echo "FAIL: missing expected entry file require"
  echo "Missing: ${EXPECTED_B}"
  exit 1
fi

echo "PASS: integration test succeeded"
