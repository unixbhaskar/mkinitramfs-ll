#!/bin/zsh
# $Id: mkinitramfs-ll/sqfsd/sdr.zsh,v 0.5.1.0 2012/05/09 23:36:10 -tclover Exp $
revision=0.5.1.0
usage() {
  cat <<-EOF
  usage: ${(%):-%1x} [-update|-remove] [-r|-sqfsdir<dir>] -d|-sqfsd:<dir>:<dir>

  -r|-sqfsdir <dir>        override default value 'sqfsdir=/sqfsd', if not changed
  -d|-sqfsd <dir>          colon seperated list of directory-ies without the leading '/'
  -f|-fstab                whether to write the necessary mount lines to '/etc/fstab'
  -b|-bsize 131072         use [128k] 131072 bytes block size, which is the default values
  -c|-comp 'xz -Xbjc x86'  use xz compressor, optionaly, one can append extra arguments...
  -e|-exclude <dir>        collon separated list of directories to exlude from .sfs image
  -o|-offset <int>         offset used for rebuilding squashed directories, default is 10%
  -U|-update               update the underlying source directory e.g. bin:sbin:lib32:lib64
  -R|-remove               remove the underlying source directory e.g. usr:opt:\${PORTDIR}
  -n|-nomount              do not remount .sfs file nor aufs after rebuilding/updating 
  -u|-usage                print this help/usage and exit
  -v|-version              print version string and exit
	
  usages:
  # squash directries which will speed up system and portage, and the underlying files 
  # system will take much less space especially if there are numerous small files.
  ${(%):-%1x} -remove -dvar/db:var/cache/edb
  # [re-]build system related squashed directories and update the sources directories
  ${(%):-%1x} -update -dbin:sbin:lib32:lib64
EOF
exit 0
}
if [[ $# = 0 ]] { usage
} else { zmodload zsh/zutil
	zparseopts -E -D -K -A opts r: sqfsdir: d: sqfsd: f fstab b: bsize: n nomount \
		c: comp: e: excl: o: offset: U update R remove u usage v version || usage
	if [[ $# != 0 ]] || [[ -n ${(k)opts[-u]} ]] || [[ -n ${(k)opts[-usage]} ]] { usage }
	if [[ -n ${(k)opts[-v]} ]] || [[ -n ${(k)opts[-version]} ]] {
		print "${(%):-%1x}-$revision"; exit 0 }
}
if [[ -n $(uname -m | grep 64) ]] { opts[-arch]=64 } else { opts[-arch]=32 }
:	${opts[-sqfsdir]:=${opts[-r]:-/sqfsd}}
:	${opts[-offset]:=$opts[-o]}
:	${opts[-arch]:=$opts[-a]}
:	${opts[-exclude]:=$opts[-e]}
:	${opts[-bsize]:=${opts[-b]:-131072}}
:	${opts[-comp]:=${opts[-c]:-gzip}}
info() 	{ print -P " %B%F{green}*%b%f $@" }
error() { print -P " %B%F{red}*%b%f $@" }
die()   { error $@; exit 1 }
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'
setopt NULL_GLOB
sqfsd()
{
	mkdir -p ${opts[-sqfsdir]}/${dir}/{ro,rw} || die "failed to create ${dir}/{ro,rw} dirs"
	mksquashfs /${dir} ${opts[-sqfsdir]}/${dir}.tmp.sfs -b ${opts[-bsize]} -comp ${=opts[-comp]} \
		${=opts[-exclude]:+-e ${(pws,:,)opts[-exclude]}} >/dev/null || die "failed to build ${dir}.sfs img"
	if [[ $dir = lib${opts[-arch]} ]] { # move rc-svcdir and cachedir
		mkdir -p /var/{lib/init.d,cache/splash}
		mount -move /${dir}/splash/cache /var/cache/splash &>/dev/null \
			|| die "failed to move cachedir."
		mount -move /${dir}/rc/init.d /var/lib/init.d &>/dev/null \
			|| die "failed to move rc-svcdir." 
	}
	if [[ -n $(mount -t aufs | grep -w ${dir}) ]] {
	umount -l /${dir} &>/dev/null || die "failed to umount ${dir} aufs branch" }
	if [[ -n $(mount -t squashfs | grep ${opts[-sqfsdir]}/${dir}/ro) ]] {
		umount -l ${opts[-sqfsdir]}/${dir}/ro &>/dev/null || die "failed to umount sfs img" 
	}
	rm -rf ${opts[-sqfsdir]}/${dir}/rw/* || die "failed to clean up ${opts[-sqfsdir]}/${dir}/rw"
	[[ -e ${opts[-sqfsdir]}/${dir}.sfs ]] && rm -f ${opts[-sqfsdir]}/${dir}.sfs 
	mv ${opts[-sqfsdir]}/${dir}.tmp.sfs ${opts[-sqfsdir]}/${dir}.sfs || \
		die "failed to move ${dir}.tmp.sfs img"
	if [[ -n ${(k)opts[-fstab]} || -n ${(k)opts[-fstab]} ]] {
		echo "${opts[-sqfsdir]}/${dir}.sfs ${opts[-sqfsdir]}/${dir}/ro squashfs nodev,loop,ro 0 0" \
			>> /etc/fstab || die "fstab write failure 1."
		echo "${dir} /${dir} aufs \
			nodev,udba=reval,br:${opts[-sqfsdir]}/${dir}/rw:${opts[-sqfsdir]}/${dir}/ro 0 0" \
			>> /etc/fstab || die "fstab write failure 2." 
	}
if [[ -n ${(k)opts[-n]} ]] || [[ -n ${(k)opts[-nomount]} ]] { continue } else {
	mount -t squashfs ${opts[-sqfsdir]}/${dir}.sfs ${opts[-sqfsdir]}/${dir}/ro -o nodev,loop,ro \
		&>/dev/null || die "failed to mount ${dir}.sfs img"
	if [[ -n ${(k)opts[-R]} ]] || [[ -n ${(k)opts[-remove]} ]] { 
		rm -rf /${dir}/* || die "failed to clean up ${opts[-sqfsdir]}/${dir}"
	} elif [[ -n ${(k)opts[-U]} ]] || [[ -n ${(k)opts[-update]} ]] { 
		cp -ar ${opts[-sqfsdir]}/${dir}/ro /${dir}ro
		mv /${dir}{,rm} && mv /${dir}{ro,} && rm -fr /${dir}rm || info "failed to update ${dir}"
	}
	mount -t aufs ${dir} /${dir} -o \
		nodev,udba=reval,br:${opts[-sqfsdir]}/${dir}/rw:${opts[-sqfsdir]}/${dir}/ro \
		&>/dev/null || die "failed to mount ${dir} aufs branch"
}
	if [[ ${dir} = lib${opts[-arch]} ]] { # move back rc-svcdir and cachedir
		mount -move /var/cache/splash "/${dir}/splash/cache" &>/dev/nul \
			|| die "failed to move back cachedir."
		mount -move /var/lib/init.d "/${dir}/rc/init.d" &>/dev/null \
			|| die "failed to move back rc-svcdir." }
	print -P "%F{green}>>> ...squashed ${dir} sucessfully [re]build%f"
}
for dir (${(pws,:,)opts[-sqfsd]} ${(pws,:,)opts[-d]}) {
	if [[ -e /sqfsd/${dir}.sfs ]] { 
		if [[ ${opts[-offset]:-10} != 0 ]] {
			ro_size=${$(du -sk ${opts[-sqfsdir]}/${dir}/ro)[1]}
			rw_size=${$(du -sk ${opts[-sqfsdir]}/${dir}/rw)[1]}
			if (( (${rw_size}*100/${ro_size}) <= ${opts[-offset]:-10} )) { 
				info "${dir}: skiping... there's \`-o' options to change the offset"
			} else { print -P "%F{green}>>> updating squashed ${dir}...%f"; sqfsd }
		} else { print -P "%F{green}>>> updating squashed ${dir}...%f"; sqfsd }
	} else { print -P "%F{green}>>> building squashed ${dir}...%f"; sqfsd }
}
unset opts ro_size rw_size
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
