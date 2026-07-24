#!/bin/sh

### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=LineageOS 23.2 + SukiSU-Ultra for OnePlus 8T (kebab)
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=kebab
device.name2=OnePlus8T
device.name3=oneplus8t
device.name4=KB2000
device.name5=KB2001
device.name6=KB2003
device.name7=KB2005
device.name8=KB2007
device.name9=OP8T
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; }
# end properties

block=boot;
is_slot_device=1;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

. tools/ak3-core.sh

## boot install
split_boot
flash_boot
## end install