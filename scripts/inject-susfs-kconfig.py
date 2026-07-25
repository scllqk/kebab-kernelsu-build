#!/usr/bin/env python3
"""Inject SUSFS Kconfig entries into KernelSU Kconfig file.
The SUSFS kernel patch (50_add_susfs*) modifies source files to #include 
<linux/susfs.h> and depend on CONFIG_KSU_SUSFS. The KSU patch 
(10_enable_susfs_for_ksu.patch) adds Kconfig entries but may be partially
applied or broken. This script ensures valid Kconfig entries exist and
the file is syntactically valid."""
import sys, re
kconfig_path = sys.argv[1]

entries = [
    ('KSU_SUSFS', 'SUSFS support'),
    ('KSU_SUSFS_SUS_PATH', 'SUSFS path hiding'),
    ('KSU_SUSFS_SUS_MOUNT', 'SUSFS mount hiding'),
    ('KSU_SUSFS_SPOOF_UNAME', 'SUSFS uname spoof'),
    ('KSU_SUSFS_ENABLE_LOG', 'SUSFS debug log (default n)'),
]

with open(kconfig_path, 'r') as f:
    content = f.read()

# Fix any trailing whitespace lines that could cause parser errors
content = re.sub(r'[ \t]+$', '', content, flags=re.MULTILINE)
if not content.endswith('\n'):
    content += '\n'

for name, desc in entries:
    pattern = rf'^config\s+{re.escape(name)}\b'
    if re.search(pattern, content, re.MULTILINE):
        print(f'  Kconfig entry {name} already exists')
        continue
    
    is_default_n = 'default n' in desc
    default = 'n' if is_default_n else 'y'
    entry = f'\nconfig {name}\n\tbool "{desc}"\n\tdefault {default}\n'
    content += entry
    print(f'  Added Kconfig entry: {name}')

# Write back
with open(kconfig_path, 'w') as f:
    f.write(content)

# Quick validation: count "config" lines
count = len(re.findall(r'^config\s+\w+', content, re.MULTILINE))
print(f'  Kconfig file: {count} entries, {len(content)} bytes')
