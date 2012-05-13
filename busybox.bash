#!/bin/bash
# $Id: mkinitramfs-ll/busybox.bash,v 0.6.0 2012/05/14 00:42:24 -tclover Exp $
usage() {
  cat <<-EOF
  usage: ${0##*/} [-m|--minimal] [OPTIONS]
  -i, --install             install busybox with symliks to \${opts[-bindir]}, require -b
  -n, --minimal             build busybox with minimal applets, default is full applets
  -U, --ucl-arch i386       ARCH string needed to build busybox against uClibc	
  -B, --bindir [bin]        copy builded binary to <bin> directory
  -u, --usage               print the usage/help and exit
EOF
exit $?
}
opt=$(getopt -l install,keymap:,minimal,ucl-arch,usage,bindir: \
	-o inuDU:B:Y: -n ${0##*/} -- "$@" || usage)
eval set -- "$opt"
[[ -z "${opts[*]}" ]] && declare -A opts
while [[ $# > 0 ]]; do
	case $1 in
		-i|--intsall) opts[install]=y; shift 2;;
		-n|--minimal) opts[minimal]=y; shift 2;;
		-B|--bindir) opts[bindir]="${2}"; shift 2;;
		-U|--ucl-arch) opts[U]=${2}; shift 2;;
		-y|--keymap) opts[keymap]="${2}"; shift 2;;
		--) shift; break;;
		-u|--usage|*) usage;;
	esac
done
[[ -n "${opts[workdir]}" ]] || opts[workdir]="$(pwd)"
[[ -n "${opts[bindir]}" ]] || opts[bindir]="${opts[workdir]}"/bin
[[ -f mkifs-ll.conf.bash ]] && source mkifs-ll.conf.bash
mkdir -p "${opts[bindir]}"
error() { echo -ne " \e[1;31m* \e[0m$@\n"; }
die()   { error "$@"; exit 1; }
cd "${PORTDIR:-/usr/portage}"/sys-apps/busybox || die
opts[bbt]=$(emerge -pvO busybox | grep -o "busybox-[-0-9.r]*")
ebuild ${opts[bbt]}.ebuild clean || die "clean failed"
ebuild ${opts[bbt]}.ebuild unpack || die "unpack failed"
cd "${PORTAGE_TMPDIR:-/var/tmp}"/portage/sys-apps/${opts[bbt]}/work/${opts[bbt]} || die
if [[ -n "${opts[minimal]}" ]]; then make allnoconfig || die
	sed -e "s|# CONFIG_INSTALL_NO_USR is not set|CONFIG_INSTALL_NO_USR=y|" \
	-e "s|CONFIG_FEATURE_SH_IS_NONE=y|# CONFIG_FEATURE_SH_IS_NONE is not set|" \
	-e "s|# CONFIG_FEATURE_SH_IS_ASH is not set|CONFIG_FEATURE_SH_IS_ASH=y|" \
	-e "s|# CONFIG_ASH_BUILTIN_ECHO is not set|CONFIG_ASH_BUILTIN_ECHO=y|" \
	-e "s|# CONFIG_BASENAME is not set|CONFIG_BASENAME=y|" \
	-e "s|# CONFIG_CAT is not set|CONFIG_CAT=y|" -e "s|# CONFIG_CP is not set|CONFIG_CP=y|" \
	-e "s|# CONFIG_STATIC is not set|CONFIG_STATIC=y|" -e "s|# CONFIG_MV is not set|CONFIG_MV=y|" \
	-e "s|# CONFIG_CUT is not set|CONFIG_CUT=y|" -e "s|# CONFIG_FDISK is not set|CONFIG_FDISK=y|" \
	-e "s|# CONFIG_MKDIR is not set|CONFIG_MKDIR=y|" -e "s|# CONFIG_MKNOD is not set|CONFIG_MKNOD=y|" \
	-e "s|# CONFIG_FINDFS is not set|CONFIG_FINDFS=y|" -e "s|# CONFIG_FSCK is not set|CONFIG_FSCK=y|" \
	-e "s|# CONFIG_KBD_MODE is not set|CONFIG_KBD_MODE=y|" -e "s|# CONFIG_ASH is not set|CONFIG_ASH=y|" \
	-e "s|# CONFIG_INIT is not set|CONFIG_INIT=y|" -e "s|# CONFIG_LOADFONT is not set|CONFIG_LOADFONT=y|" \
	-e "s|# CONFIG_MODPROBE is not set|CONFIG_MODPROBE=y|" -e "s|# CONFIG_BLKID is not set|CONFIG_BLKID=y|" \
	-e "s|# CONFIG_RM is not set|CONFIG_RM=y|" -e "s|# CONFIG_BLKID_TYPE is not set|CONFIG_BLKID_TYPE=y|" \
	-e "s|# CONFIG_MOUNT is not set|CONFIG_MOUNT=y|" -e "s|# CONFIG_RMMOD is not set|CONFIG_RMMOD=y|" \
	-e "s|# CONFIG_MDEV is not set|CONFIG_MDEV=y|" -e "s|# CONFIG_UMOUNT is not set|CONFIG_UMOUNT=y|" \
	-e "s|# CONFIG_SED is not set|CONFIG_SED=y|" -e "s|# CONFIG_SETFONT is not set|CONFIG_SETFONT=y|" \
	-e "s|# CONFIG_HEAD is not set|CONFIG_HEAD=y|" -e "s|# CONFIG_GREP is not set|CONFIG_GREP=y|" \
	-e "s|# CONFIG_SLEEP is not set|CONFIG_SLEEP=y|" -e "s|# CONFIG_TR is not set|CONFIG_TR=y|" \
	-e "s|# CONFIG_HEAD is not set|CONFIG_HEAD=y|" -e "s|# CONFIG_TEST is not set|CONFIG_TEST=y|" \
	-e "s|# CONFIG_TTY is not set|CONFIG_TTY=y|" -e "s|# CONFIG_WHICH is not set|CONFIG_WHICH=y|" \
	-e "s|# CONFIG_LOADKMAP is not set|CONFIG_LOADKMAP=y|" -e "s|# CONFIG_LN is not set|CONFIG_LN=y|" \
	-e "s|# CONFIG_SWITCH_ROOT is not set|CONFIG_SWITCH_ROOT=y|" -i .config || die "minimal cfg failed"
else make defconfig || die "defconfig failed"
	sed -e "s|# CONFIG_STATIC is not set|CONFIG_STATIC=y|" \
	-e "s|# CONFIG_INSTALL_NO_USR is not set|CONFIG_INSTALL_NO_USR=y|" -i .config || die "config failed"
fi
# For uClibc users, you need to adjust the cross compiler prefix properly (i386-uclibc-)
if [[ -n "${opts[U]}" ]]; then
	sed -e "s|CONFIG_CROSS_COMPILER_PREFIX=\"\"|CONFIG_CROSS_COMPILER_PREFIX=\"${opts[U]}\"|" \
		-i .config || die "setting uClib ARCH failed"
fi
make && make busybox.links || die "failed to build busybox"
if [[ -n "${opts[install]}" ]]; then
	if [[ -e "${opts[tmpdir]}" ]]; then
			make install CONFIG_PREFIX="${opts[tmpdir]}"/busybox
			rm -rf "${opts[tmpdir]}"/busybox
	fi
	applets/install.sh "${opts[bindir]}" --symlinks
fi
cp -a busybox "${opts[bindir]}"/ || die "failed to copy busybox binary"
cp busybox.links "${opts[bindir]}"/applets || die "failed to copy applets"
cd "${PORTDIR:-/usr/portage}"/sys-apps/busybox || die
ebuild ${opts[bbt]}.ebuild clean || die
cd "${opts[workdir]}" || die
unset -v opts[bbt] opts[install] opts[minimal] opts[U] km_in km_out
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
