#!/bin/bash
# SukiSU-Ultra 集成脚本 (修改版: KernelSU -> SukiSU-Ultra + KPM)
set -e

KERNELSU_VERSION="${1:-main}"
KERNEL_DIR="${2:-$(pwd)}"

echo "========================================"
echo "SukiSU-Ultra 集成脚本"
echo "版本: ${KERNELSU_VERSION}"
echo "内核目录: ${KERNEL_DIR}"
echo "========================================"

cd "$KERNEL_DIR"

echo "[1/2] 下载 SukiSU-Ultra 集成脚本..."
curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" -o /tmp/sukisu-setup.sh
chmod +x /tmp/sukisu-setup.sh

echo "[2/2] 运行集成脚本..."
bash /tmp/sukisu-setup.sh "$KERNELSU_VERSION"

echo ""
echo "SukiSU-Ultra 集成完成!"
