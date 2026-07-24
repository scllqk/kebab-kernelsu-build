#!/bin/bash
# KernelSU 集成脚本 (保持标准 KernelSU，手动添加 KPM)
set -e

KERNELSU_VERSION="${1:-main}"
KERNEL_DIR="${2:-$(pwd)}"

echo "========================================"
echo "KernelSU 集成脚本 (手动 KPM)"
echo "版本: ${KERNELSU_VERSION}"
echo "内核目录: ${KERNEL_DIR}"
echo "========================================"

cd "$KERNEL_DIR"

echo "[1/2] 下载 KernelSU 集成脚本..."
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" -o /tmp/kernelsu-setup.sh
chmod +x /tmp/kernelsu-setup.sh

echo "[2/2] 运行集成脚本..."
bash /tmp/kernelsu-setup.sh "$KERNELSU_VERSION"

echo ""
echo "KernelSU 集成完成!"
echo "KPM 和 SUSFS 由 workflow 手动配置"
