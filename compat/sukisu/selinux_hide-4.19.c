// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Linux 4.19 stub for SukiSU-Ultra selinux_hide.
 *
 * The full feature relies on modern SELinux internals (status_page,
 * status_lock, selinux_policy layout) that do not exist on 4.19.
 * Keep the public symbols so the rest of KernelSU links cleanly.
 */
#include "feature/selinux_hide.h"
#include "klog.h" // IWYU pragma: keep

void ksu_selinux_hide_init(void)
{
	pr_info("selinux_hide: disabled on Linux 4.19\n");
}

void ksu_selinux_hide_exit(void)
{
}

void ksu_selinux_hide_drop_backup_if_unused(void)
{
}

void ksu_selinux_hide_handle_second_stage(void)
{
}

void ksu_selinux_hide_handle_post_fs_data(void)
{
}
