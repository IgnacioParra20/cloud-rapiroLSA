#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
PACKAGE_PATH="${BUILD_DIR}/lambda_function.zip"

mkdir -p "${BUILD_DIR}"
rm -f "${PACKAGE_PATH}"

(
  cd "${ROOT_DIR}/lambda"
  zip -q -r "${PACKAGE_PATH}" app.py
)

echo "Lambda package created at ${PACKAGE_PATH}"
