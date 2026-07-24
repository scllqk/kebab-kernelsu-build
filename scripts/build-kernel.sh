#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${GITHUB_WORKSPACE:-$(pwd)}"
KERNEL_DIR="${KERNEL_DIR:-${ROOT_DIR}/kernel}"
OUT_DIR="${OUT_DIR:-${ROOT_DIR}/out}"
DIST_DIR="${ROOT_DIR}/dist"
TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-${ROOT_DIR}/toolchain}"

: "${KERNEL_REF:=lineage-23.2}"
: "${SUKISU_REF:=v4.1.3}"
: "${CLANG_VERSION:=clang-r563880c}"

export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"
export ARCH=arm64
export LLVM=1
export LLVM_IAS=1
export KBUILD_BUILD_USER=github-actions
export KBUILD_BUILD_HOST=github

mkdir -p "${OUT_DIR}" "${DIST_DIR}"

echo "Integrating SukiSU-Ultra ${SUKISU_REF}"
(
  cd "${KERNEL_DIR}"
  curl --fail --location --silent --show-error \
    "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/${SUKISU_REF}/kernel/setup.sh" \
    | sh -s "${SUKISU_REF}"
)

echo "Backporting path_umount for Linux 4.19"
if ! grep -q '^int path_umount(struct path \*path, int flags)' \
  "${KERNEL_DIR}/fs/namespace.c"; then
  git -C "${KERNEL_DIR}" apply "${ROOT_DIR}/patches/path-umount-4.19.patch"
fi

echo "Backporting path_mount for Linux 4.19 (SukiSU individual mnt ns)"
if ! grep -q '^int path_mount(const char \*dev_name, struct path \*path' \
  "${KERNEL_DIR}/fs/namespace.c"; then
  python3 - <<PY
from pathlib import Path
p = Path(r"""${KERNEL_DIR}/fs/namespace.c""")
t = p.read_text()
marker = "int path_mount(const char *dev_name, struct path *path"
if marker in t:
    print("path_mount already present")
    raise SystemExit(0)
# Insert near end of file so do_change_type is already defined above.
fn = """
/*
 * Minimal path_mount for Linux 4.19 (SukiSU-Ultra needs MS_PRIVATE|MS_REC).
 * Full path_mount arrived later; do_change_type is static in this file.
 */
int path_mount(const char *dev_name, struct path *path,
	       const char *type_page, unsigned long flags, void *data_page)
{
	unsigned long prop = flags & (MS_SHARED | MS_PRIVATE | MS_SLAVE |
				      MS_UNBINDABLE | MS_REC);

	if (prop && !(flags & ~prop) && !dev_name && !type_page && !data_page)
		return do_change_type(path, (int)flags);

	return -ENOSYS;
}
"""
# Insert after do_change_type so the static helper is already defined.
idx = t.find("static int do_change_type(struct path *path, int flag)")
if idx < 0:
    idx = t.find("static int do_change_type(struct path *path, int flags)")
if idx >= 0:
    end = t.find("\n}\n", idx)
    if end < 0:
        raise SystemExit("do_change_type end not found")
    end += len("\n}\n")
    t = t[:end] + fn + t[end:]
else:
    # Fallback: append at end of file.
    t = t.rstrip() + "\n" + fn + "\n"
p.write_text(t)
print("injected path_mount into", p)
PY
fi

echo "Applying the Linux 4.19 access_ok compatibility shim for SukiSU-Ultra KPM"
if ! grep -q '^static inline bool sukisu_access_ok_compat' \
  "${KERNEL_DIR}/KernelSU/kernel/kpm/kpm.c"; then
  git -C "${KERNEL_DIR}/KernelSU" apply \
    "${ROOT_DIR}/patches/sukisu-kpm-access-ok-4.19.patch"
fi

echo "Backporting MODULE_IMPORT_NS compatibility for SukiSU-Ultra"
if ! grep -q '^#define MODULE_IMPORT_NS(ns)' \
  "${KERNEL_DIR}/KernelSU/kernel/core/init.c"; then
  git -C "${KERNEL_DIR}/KernelSU" apply \
    "${ROOT_DIR}/patches/sukisu-module-import-ns-4.19.patch"
fi

echo "Disabling unavailable VFS wrapper methods on Linux 4.19"
if ! grep -q '^#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 0, 0)$' \
  "${KERNEL_DIR}/KernelSU/kernel/infra/file_wrapper.c"; then
  git -C "${KERNEL_DIR}/KernelSU" apply \
    "${ROOT_DIR}/patches/sukisu-file-wrapper-4.19.patch"
fi

echo "Backporting the native seccomp syscall count for Linux 4.19"
if ! grep -q '^#define SECCOMP_ARCH_NATIVE_NR __NR_syscalls' \
  "${KERNEL_DIR}/KernelSU/kernel/infra/seccomp_cache.c"; then
  git -C "${KERNEL_DIR}/KernelSU" apply \
    "${ROOT_DIR}/patches/sukisu-seccomp-nr-4.19.patch"
fi

echo "Using the Linux 4.19 mount header layout for SukiSU-Ultra"
if grep -q '^#include <uapi/linux/mount.h>' \
  "${KERNEL_DIR}/KernelSU/kernel/infra/su_mount_ns.c"; then
  git -C "${KERNEL_DIR}/KernelSU" apply \
    "${ROOT_DIR}/patches/sukisu-mount-header-4.19.patch"
fi

echo "Backporting the Linux 4.19 fsnotify observer callback"
if ! grep -q '^static int ksu_handle_event(struct fsnotify_group' \
  "${KERNEL_DIR}/KernelSU/kernel/manager/pkg_observer.c"; then
  git -C "${KERNEL_DIR}/KernelSU" apply \
    "${ROOT_DIR}/patches/sukisu-fsnotify-4.19.patch"
fi

echo "Backporting the Linux 4.19 task_work API for SukiSU-Ultra"
if ! grep -q '^#define KSU_TWA_RESUME true' \
  "${KERNEL_DIR}/KernelSU/kernel/policy/allowlist.c"; then
  git -C "${KERNEL_DIR}/KernelSU" apply \
    "${ROOT_DIR}/patches/sukisu-task-work-4.19.patch"
fi

echo "Gating the newer seccomp filter counter on Linux 4.19"
if ! grep -q '^#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 0, 0)$' \
  "${KERNEL_DIR}/KernelSU/kernel/policy/app_profile.c"; then
  git -C "${KERNEL_DIR}/KernelSU" apply \
    "${ROOT_DIR}/patches/sukisu-seccomp-filter-count-4.19.patch"
fi

echo "Skipping seccomp_filter_release on Linux 4.19"
if grep -q 'seccomp_filter_release(fake)' \
  "${KERNEL_DIR}/KernelSU/kernel/policy/app_profile.c" && \
  ! grep -q 'KERNEL_VERSION(5, 9, 0)' \
  "${KERNEL_DIR}/KernelSU/kernel/policy/app_profile.c"; then
  python3 - <<PY
from pathlib import Path
p = Path(r"""${KERNEL_DIR}/KernelSU/kernel/policy/app_profile.c""")
t = p.read_text()
old = "void seccomp_filter_release(struct task_struct *tsk);"
new = """#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 9, 0)
void seccomp_filter_release(struct task_struct *tsk);
#endif"""
if old in t:
    t = t.replace(old, new, 1)
call = "    seccomp_filter_release(fake);"
call_new = """#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 9, 0)
    seccomp_filter_release(fake);
#endif"""
if call in t:
    t = t.replace(call, call_new, 1)
p.write_text(t)
print("gated seccomp_filter_release")
PY
fi

echo "Backporting the Linux 4.19 SELinux policy layout for SukiSU-Ultra"
if ! grep -q '^static DEFINE_MUTEX(ksu_rules);' \
  "${KERNEL_DIR}/KernelSU/kernel/selinux/rules.c"; then
  git -C "${KERNEL_DIR}/KernelSU" apply \
    "${ROOT_DIR}/patches/sukisu-selinux-policy-4.19.patch"
fi

echo "Using the Linux 4.19 SELinux policydb implementation"
cp "${ROOT_DIR}/compat/sukisu/sepolicy-4.19.c" \
  "${KERNEL_DIR}/KernelSU/kernel/selinux/sepolicy.c"

echo "Using the Linux 4.19 selinux_hide stub (modern SELinux internals missing)"
cp "${ROOT_DIR}/compat/sukisu/selinux_hide-4.19.c" \
  "${KERNEL_DIR}/KernelSU/kernel/feature/selinux_hide.c"

echo "Backporting minmax/nofault helpers for SukiSU sulog on Linux 4.19"
if grep -q '#include <linux/minmax.h>' \
  "${KERNEL_DIR}/KernelSU/kernel/sulog/event.c"; then
  git -C "${KERNEL_DIR}/KernelSU" apply \
    "${ROOT_DIR}/patches/sukisu-minmax-4.19.patch"
fi

echo "Exposing tasklist/init_task symbols for SukiSU supercall on Linux 4.19"
if ! grep -q '#include <linux/init_task.h>' \
  "${KERNEL_DIR}/KernelSU/kernel/supercall/dispatch.c"; then
  git -C "${KERNEL_DIR}/KernelSU" apply \
    "${ROOT_DIR}/patches/sukisu-tasklist-4.19.patch"
fi

echo "Backporting TWA_RESUME for SukiSU supercall on Linux 4.19"
SUPERCALL_C="${KERNEL_DIR}/KernelSU/kernel/supercall/supercall.c"
if grep -q 'task_work_add(current, &tw->cb, TWA_RESUME)' "${SUPERCALL_C}"; then
  if ! git -C "${KERNEL_DIR}/KernelSU" apply \
    "${ROOT_DIR}/patches/sukisu-supercall-task-work-4.19.patch"; then
    echo "git apply failed; rewriting TWA_RESUME via sed"
    if ! grep -q 'KSU_TWA_RESUME' "${SUPERCALL_C}"; then
      sed -i '/#include <linux\/version.h>/a\
\
/* Linux 4.19 task_work_add takes a bool notify flag, not TWA_*. */\
#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 0, 0)\
#define KSU_TWA_RESUME true\
#else\
#define KSU_TWA_RESUME TWA_RESUME\
#endif' "${SUPERCALL_C}"
    fi
    sed -i 's/task_work_add(current, \&tw->cb, TWA_RESUME)/task_work_add(current, \&tw->cb, KSU_TWA_RESUME)/g' \
      "${SUPERCALL_C}"
  fi
fi

make_args=(
  -C "${KERNEL_DIR}"
  O="${OUT_DIR}"
  ARCH=arm64
  LLVM=1
  LLVM_IAS=1
  CC=clang
  LD=ld.lld
  AR=llvm-ar
  NM=llvm-nm
  OBJCOPY=llvm-objcopy
  OBJDUMP=llvm-objdump
  READELF=llvm-readelf
  STRIP=llvm-strip
  HOSTCC=clang
  HOSTCXX=clang++
  DTC_EXT=dtc
  BRAND_SHOW_FLAG=oneplus
)

echo "Generating the LineageOS kernel configuration"
cp "${KERNEL_DIR}/arch/arm64/configs/vendor/kona-perf_defconfig" "${OUT_DIR}/.config"
make "${make_args[@]}" olddefconfig
"${KERNEL_DIR}/scripts/kconfig/merge_config.sh" -m -O "${OUT_DIR}" \
  "${OUT_DIR}/.config" \
  "${KERNEL_DIR}/arch/arm64/configs/vendor/oplus.config"
make "${make_args[@]}" olddefconfig
"${KERNEL_DIR}/scripts/kconfig/merge_config.sh" -m -O "${OUT_DIR}" \
  "${OUT_DIR}/.config" \
  "${ROOT_DIR}/configs/sukisu-ultra.config"
make "${make_args[@]}" olddefconfig

for required in \
  CONFIG_KSU=y \
  CONFIG_KSU_MANUAL_SU=y \
  CONFIG_KPM=y \
  CONFIG_KPROBES=y \
  CONFIG_KRETPROBES=y \
  CONFIG_HAVE_SYSCALL_TRACEPOINTS=y \
  CONFIG_KALLSYMS=y \
  CONFIG_KALLSYMS_ALL=y \
  CONFIG_EXT4_FS=y \
  CONFIG_OVERLAY_FS=y; do
  grep -qx "${required}" "${OUT_DIR}/.config" || {
    echo "Required setting is missing after olddefconfig: ${required}" >&2
    exit 1
  }
done

echo "Building Image"
make -j"$(nproc)" "${make_args[@]}" Image

image_path="${OUT_DIR}/arch/arm64/boot/Image"
test -s "${image_path}"
cp "${image_path}" "${DIST_DIR}/Image"
cp "${OUT_DIR}/.config" "${DIST_DIR}/kernel.config"

kernel_sha="$(git -C "${KERNEL_DIR}" rev-parse HEAD)"
sukisu_sha="$(git -C "${KERNEL_DIR}/KernelSU" rev-parse HEAD)"
kernel_release="$(make -s "${make_args[@]}" kernelrelease)"

cat > "${DIST_DIR}/build-info.txt" <<EOF
device=kebab
rom=lineage-23.2
kernel_repository=https://github.com/LineageOS/android_kernel_oneplus_sm8250
kernel_ref=${KERNEL_REF}
kernel_commit=${kernel_sha}
kernel_release=${kernel_release}
sukisu_repository=https://github.com/SukiSU-Ultra/SukiSU-Ultra
sukisu_ref=${SUKISU_REF}
sukisu_commit=${sukisu_sha}
clang_version=${CLANG_VERSION}
compiler=$(clang --version | head -n 1)
EOF

echo "KERNEL_SHA=${kernel_sha}" >> "${GITHUB_ENV}"
echo "SUKISU_SHA=${sukisu_sha}" >> "${GITHUB_ENV}"
echo "KERNEL_RELEASE=${kernel_release}" >> "${GITHUB_ENV}"
