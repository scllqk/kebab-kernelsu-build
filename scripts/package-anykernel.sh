#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${GITHUB_WORKSPACE:-$(pwd)}"
DIST_DIR="${ROOT_DIR}/dist"
PACKAGE_DIR="${ROOT_DIR}/AnyKernel3"
SHORT_SHA="${KERNEL_SHA:0:7}"
ZIP_NAME="kebab-lineage-23.2-sukisu-ultra-${SHORT_SHA}.zip"

git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git "${PACKAGE_DIR}"
rm -rf "${PACKAGE_DIR}/.git" "${PACKAGE_DIR}/.github"
cp "${ROOT_DIR}/packaging/anykernel.sh" "${PACKAGE_DIR}/anykernel.sh"
cp "${DIST_DIR}/Image" "${PACKAGE_DIR}/Image"
cp "${DIST_DIR}/build-info.txt" "${PACKAGE_DIR}/build-info.txt"

(
  cd "${PACKAGE_DIR}"
  zip -r9 "${DIST_DIR}/${ZIP_NAME}" . \
    -x '*.git*' 'README.md' '*placeholder'
)

sha256sum "${DIST_DIR}/Image" "${DIST_DIR}/${ZIP_NAME}" > "${DIST_DIR}/SHA256SUMS"
