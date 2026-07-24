#!/bin/bash
# SukiSU-Ultra 集成脚本 (修改版: KernelSU -> SukiSU-Ultra + KPM)
# 用于将 SukiSU-Ultra 集成到 LineageOS 内核，开启 KPM 和 SUSFS

set -e

KERNELSU_VERSION="${1:-main}"
KERNEL_DIR="${2:-$(pwd)}"

echo "========================================"
echo "SukiSU-Ultra 集成脚本"
echo "版本: ${KERNELSU_VERSION}"
echo "内核目录: ${KERNEL_DIR}"
echo "========================================"

cd "$KERNEL_DIR"

# 下载并运行 SukiSU-Ultra 官方 setup 脚本
echo "[1/2] 下载 SukiSU-Ultra 集成脚本..."
curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" -o /tmp/sukisu-setup.sh
chmod +x /tmp/sukisu-setup.sh

echo "[2/2] 运行集成脚本..."
bash /tmp/sukisu-setup.sh "$KERNELSU_VERSION"

echo ""
echo "SukiSU-Ultra 集成完成!"
echo ""
echo "下一步:"
echo "1. 在 defconfig 中添加 CONFIG_KSU=y"
echo "2. 确保 CONFIG_KPROBES=y 已启用"
echo "3. 添加 CONFIG_KPM=y 开启 KPM 支持"
echo "4. 添加 CONFIG_KSU_SUSFS=y 开启 SUSFS 隐藏"
