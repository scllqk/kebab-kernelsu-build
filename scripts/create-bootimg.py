#!/usr/bin/env python3
"""Pure-Python boot image tool: extract ramdisk from stock boot, repack with new kernel.
Android boot image header v2 support. No external dependencies."""

import struct, sys, os

PAGE_SIZE = 4096

def read_boot_header(path):
    with open(path, 'rb') as f:
        h = f.read(PAGE_SIZE)
    magic = h[:8]
    if magic != b'ANDROID!':
        print(f"  Warning: magic={h[:8]} (expected ANDROID!)")
    kernel_size = struct.unpack_from('I', h, 8)[0]
    ramdisk_size = struct.unpack_from('I', h, 16)[0]
    second_size = struct.unpack_from('I', h, 24)[0]
    page_size = struct.unpack_from('I', h, 36)[0]
    header_version = struct.unpack_from('I', h, 40)[0]
    if page_size == 0:
        page_size = PAGE_SIZE
    return {
        'kernel_size': kernel_size, 'ramdisk_size': ramdisk_size,
        'second_size': second_size, 'page_size': page_size,
        'header_version': header_version, 'header_bytes': h
    }

def page_align(offset, page_size):
    return (offset + page_size - 1) // page_size * page_size

def extract_ramdisk(stock_boot, output_path):
    info = read_boot_header(stock_boot)
    kernel_offset = info['page_size']
    kernel_pages = (info['kernel_size'] + info['page_size'] - 1) // info['page_size']
    ramdisk_offset = kernel_offset + kernel_pages * info['page_size']
    
    with open(stock_boot, 'rb') as f:
        f.seek(ramdisk_offset)
        ramdisk = f.read(info['ramdisk_size'])
    
    with open(output_path, 'wb') as f:
        f.write(ramdisk)
    
    print(f"  Ramdisk: {len(ramdisk)} bytes -> {output_path}")
    return info

def repack_bootimg(stock_boot, new_kernel, ramdisk_file, output_path):
    info = read_boot_header(stock_boot)
    
    with open(new_kernel, 'rb') as f:
        kernel_data = f.read()
    
    with open(ramdisk_file, 'rb') as f:
        ramdisk_data = f.read()
    
    ps = info['page_size']
    
    # Build new header (copy from stock, update sizes)
    h = bytearray(info['header_bytes'])
    struct.pack_into('I', h, 8, len(kernel_data))  # kernel_size
    struct.pack_into('I', h, 16, len(ramdisk_data))  # ramdisk_size
    struct.pack_into('I', h, 24, 0)  # second_size = 0
    
    with open(output_path, 'wb') as f:
        # Header (page aligned)
        f.write(bytes(h[:ps]))
        # Pad header to page boundary
        if len(h) < ps:
            f.write(b'\x00' * (ps - len(h)))
        
        # Kernel (page aligned)
        f.write(kernel_data)
        padding = page_align(len(kernel_data), ps) - len(kernel_data)
        if padding:
            f.write(b'\x00' * padding)
        
        # Ramdisk (page aligned)
        f.write(ramdisk_data)
        padding = page_align(len(ramdisk_data), ps) - len(ramdisk_data)
        if padding:
            f.write(b'\x00' * padding)
    
    print(f"  boot.img: {os.path.getsize(output_path)} bytes")
    print(f"  Kernel: {len(kernel_data)} bytes")
    print(f"  Ramdisk: {len(ramdisk_data)} bytes")
    print(f"  Header v{info['header_version']}")

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <stock_boot.img> <new_Image> <output_boot.img>")
        sys.exit(1)
    
    stock = sys.argv[1]
    kernel = sys.argv[2]
    output = sys.argv[3]
    
    # Extract ramdisk to temp file
    ramdisk_tmp = '/tmp/boot_ramdisk.img'
    extract_ramdisk(stock, ramdisk_tmp)
    
    # Repack with new kernel
    repack_bootimg(stock, kernel, ramdisk_tmp, output)
