#!/bin/bash
# Create a flashable boot.img from the compiled kernel Image
# Usage: bash create-bootimg.sh [output_dir]

set -euo pipefail

DIST_DIR="${1:-dist}"
KERNEL_IMAGE="${DIST_DIR}/Image"

if [ ! -f "$KERNEL_IMAGE" ]; then
    echo "Error: kernel Image not found at $KERNEL_IMAGE"
    exit 1
fi

# Get the kernel release string
KERNEL_RELEASE=$(cat "${DIST_DIR}/build-info.txt" 2>/dev/null | grep kernel_release | cut -d= -f2 || echo "custom")

# Create a minimal boot.img using mkbootimg
# For OnePlus 8T (kebab), the boot image needs:
#   --kernel Image
#   --ramdisk (from device, not included here)
#   --dtb (from device)
#   --pagesize 4096
#   --base 0x00000000

echo "=== Kernel Image ==="
ls -lh "$KERNEL_IMAGE"
file "$KERNEL_IMAGE"

echo ""
echo "To create a flashable boot.img:"
echo "1. Extract your current boot image:"
echo "   adb pull /dev/block/by-name/boot_b stock_boot.img"
echo ""
echo "2. Use magiskboot to repack:"
echo "   magiskboot unpack stock_boot.img"
echo "   cp ${KERNEL_IMAGE} kernel"
echo "   magiskboot repack stock_boot.img new-boot.img"
echo ""
echo "3. Flash:"
echo "   fastboot flash boot new-boot.img"
echo ""
echo "Or use AnyKernel3 zip (already packaged):"
ls -lh "${DIST_DIR}"/*.zip 2>/dev/null || echo "   (zip not yet built)"
