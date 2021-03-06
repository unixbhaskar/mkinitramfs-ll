#!/bin/zsh
# $Id: mkinitramfs-ll/mkinitramfs-ll.zsh,v 0.12.3 2013/04/27 05:40:11 -tclover Exp $
revision=0.12.3

# @FUNCTION: usage
# @DESCRIPTION: print usages message
usage() {
  cat <<-EOF
 usage: ${(%):-%1x} [-a|-all] [-f|-font [font]] [-y|-keymap [keymap]] [options]

  -a|-all                 short hand or forme of '-q -l -luks -ggp -font -keymap'
  -f|-font [:ter-v14n]    include a colon separated list of fonts to the initramfs
  -k|-kversion 3.4.4-git  build an initramfs for kernel 3.4.4-git or else \$(uname -r)
  -c|-comp ['gzip -9']    use 'gzip -9' command instead default compression command
  -L|-luks                add LUKS support, require a sys-fs/cryptsetup[static] binary
  -l|-lvm                 add LVM support, require a static sys-fs/lvm2[static] binary
  -b|-bin :<bin>          include a colon separated list of binar-y-ies to the initramfs
  -d|-usrdir [usr]        use usr dir for user extra files, binaries, scripts, fonts...
  -g|-gpg                 add GnuPG support, require a static gnupg-1.4.x and 'options.skel'
  -p|-prefix initrd-      use 'initrd-' initramfs prefix instead of default ['initramfs-']
  -W|-workdir [<dir>]     use <dir> as a work directory to create initramfs instead of \$PWD
  -M|-module <name>       include <name> module from [..\/]mkinitramfs-ll.d module directory
  -m|-mdep [:<mod>]       include a colon separated list of kernel modules to the initramfs
     -mtuxonice [:<mod>]  include a colon separated list of kernel modules to tuxonice group
     -mremdev [:<mod>]    include a colon separated list of kernel modules to remdev  group
     -msqfsd [:<mod>]     include a colon separated list of kernel modules to sqfsd   group
     -mgpg [:<mod>]       include a colon separated list of kernel modules to gpg     group
     -mboot [:<mod>]      include a colon separated list of kernel modules to boot   group
  -s|-splash [:<theme>]   include a colon separated list of splash themes to the initramfs
  -t|-toi                 add tuxonice support for splash, require tuxoniceui_text binary
  -q|-sqfsd               add aufs(+squashfs modules +{,u}mount.aufs binaries) support
  -R|-regen               regenerate a new initramfs from an old dir with newer init
  -y|-keymap :fr-latin1   include a colon separated list of keymaps to the initramfs
  -n|-clean               clean initramfs building files, or leftover files
  -u|-usage               print this help or usage message and exit
  -v|-version             print version string and exit

 usage: without an argument, generate an default initramfs for kernel \$(uname -r)
 usgae: generate an initramfs with LUKS, GnuPG, LVM2 and aufs+squashfs support
 ${(%):-%1x} -a -k$(uname -r)
EOF
exit $?
}

# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
error() { print -P " %B%F{red}*%b%f $@" }
# @FUNCTION: info
# @DESCRIPTION: print info message to stdout
info()  { print -P " %B%F{green}*%b%f $@" }
# @FUNCTION: warn
# @DESCRIPTION: print warning message to stdout
warn()  { print -P " %B%F{red}*%b%f $@" }
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
die()   { error $@; exit 1 }
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'

# @FUNCTION: adn
# @DESCRIPTION: ADd the essential Nodes to be able to boot
adn() {
	[[ -c dev/console ]] || mknod -m 600 dev/console c 5 1 || die
	[[ -c dev/urandom ]] || mknod -m 666 dev/urandom c 1 9 || die
	[[ -c dev/random ]]  || mknod -m 666 dev/random  c 1 8 || die
	[[ -c dev/mem ]]     || mknod -m 640 dev/mem     c 1 1 && chmod 0:9 || die
	[[ -c dev/null ]]    || mknod -m 666 dev/null    c 1 3 || die
	[[ -c dev/tty ]]     || mknod -m 666 dev/tty     c 5 0 || die
	[[ -c dev/zero ]]    || mknod -m 666 dev/zero    c 1 5 || die

	for nod ($(seq 0 6)) [[ -c dev/tty${n} ]] ||
		mknod -m 600 dev/tty${nod} c 4 ${n} || die
}

setopt EXTENDED_GLOB NULL_GLOB
zmodload zsh/zutil
zparseopts -E -D -K -A opts a all q sqfsd g gpg l lvm t toi c:: comp:: \
	k: kversion: m+:: mdep+:: f+:: font+:: s:: splash:: u usage M: module: \
	v version W:: workdir::  b:: bin:: p:: prefix:: y:: keymap:: d:: usrdir:: \
	mboot+:: mgpg+:: mremdev+:: msqfsd+:: mtuxonice+:: L luks r regen n clean ||
	usage
if [[ -n ${(k)opts[-u]} ]] || [[ -n ${(k)opts[-usage]} ]] { usage }
if [[ -n ${(k)opts[-v]} ]] || [[ -n ${(k)opts[-version]} ]] {
	print "${(%):-%1x}-$revision"
	exit
}

# @VARIABLE: opts [associative array]
# @DESCRIPTION: declare if not declared while arsing options,
# hold almost every single option/variable
if [[ $# < 1 ]] { typeset -A opts }
if [[ -f mkinitramfs-ll.conf ]] { source mkinitramfs-ll.conf 
} else { die "no mkinitramfs-ll.conf found" }

# @VARIABLE: opts[-kversion]
# @DESCRIPTION: kernel version to pick up
:	${opts[-kversion]:=${opts[-k]:-$(uname -r)}}
# @VARIABLE: opts[-prefix]
# @DESCRIPTION: initramfs prefx name <$prefix.$kversion.$ext>
:	${opts[-prefix]:=${opts[-p]:-initramfs-}}
# @VARIABLE: opts[-workdir]
# @DESCRIPTION: initial working directory, where to build everythng
:	${opts[-workdir]:=${opts[-W]:-$(pwd)}}
# @VARIABLE: opts[-usrdir]
# @DESCRIPTION: usr dir path, to get extra files
:	${opts[-usrdir]:=${opts[-d]:-${opts[-workdir]}/usr}}
# @VARIABLE: opts[-comp]
# @DESCRIPTION: compression command
:	${opts[-comp]:=${opts[-c]:-xz -9 --check=crc32}}
# @VARIABLE: opts[-initdir]
# @DESCRIPTION: initramfs dir, where to put everythng before actualy generating
# an initramfs compressed image
:	${opts[-initdir]:=${opts[-workdir]}/${opts[-prefix]}${opts[-kversion]}}
# @VARIABLE: opts[-initrmafs]
# @DESCRIPTION: full to initramfs compressed image
:	${opts[-initramfs]:=/boot/${opts[-prefix]}${opts[-kversion]}}
# @VARIABLE: opts[-arch]
# @DESCRIPTION: kernel architecture
:	${opts[-arch]:=$(uname -m)}

if [[ -n ${(k)opts[-a]} ]] || [[ -n ${(k)opts[-all]} ]] { 
	opts[-f]=; opts[-g]=; opts[-l]=; opts[-q]=; opts[-L]=; opts[-y]=;
}

if [[ -n ${(k)opts[-y]} ]] || [[ -n ${(k)opts[-keymap]} ]] {
	opts[-y]+=:$(grep -E '^keymap' /etc/conf.d/keymaps | cut -d'"' -f2)
}

if [[ -n ${(k)opts[-f]} ]] || [[ -n ${(k)opts[-font]} ]] {
	opts[-f]+=:$(grep -E '^consolefont' /etc/conf.d/consolefont | cut -d'"' -f2)
	opts[-f]+=:ter-v14n:ter-g12n
}

if [[ -n $(uname -m | grep 64) ]] { opts[-arc]=64 } else { opts[-arc]=32 }

case ${opts[-comp][(w)1]} in
	bzip2)	opts[-initramfs]+=.cpio.bz2;;
	gzip) 	opts[-initramfs]+=.cpio.gz;;
	xz) 	opts[-initramfs]+=.cpio.xz;;
	lzma)	opts[-initramfs]+=.cpio.lzma;;
	lzip)	opts[-initramfs]+=.cpio.lz;;
	lzop)	opts[-initramfs]+=.cpio.lzo;;
esac

# @FUNCTION: docpio
# @DESCRIPTION: generate an initramfs image
docpio() { find . -print0 | cpio -0 -ov -Hnewc | ${=opts[-comp]} > ${opts[-initramfs]} }

if [[ -n ${(k)opts[-regen]} ]] || [[ -n ${(k)opts[-r]} ]] {
	[[ -d ${opts[-initdir]} ]] || die "${opts[-initdir]}: no old initramfs dir"
	print -P "%F{green}>>> regenerating ${opts[-initramfs]}...%f"
	pushd ${opts[-initdir]} || die
	cp -af ${opts[-usrdir]}/lib/mkinitramfs-ll/functions.sh usr/lib/mkinitramfs-ll &&
	cp -af ${opts[-workdir]}/init . && chmod 775 init || die
	docpio || die
	print -P "%F{green}>>> regenerated ${opts[-initramfs]}...%f" && exit
}

if [[ -f ${opts[-initramfs]} ]] {
	mv ${opts[-initramfs]}{,.old}
}

print -P "%F{green}>>> building ${opts[-initramfs]}...%f"

rm -rf ${opts[-initdir]}
mkdir -p ${opts[-initdir]} && pushd ${opts[-initdir]} || die
if [[ -d ${opts[-usrdir]} ]] {
	cp -ar ${opts[-usrdir]} . && rm -f usr/README* || die
	mv -f {usr/,}root 1>/dev/null 2>&1 && mv -f {usr/,}etc 1>/dev/null 2>&1 &&
	mv -f usr/lib lib${opts[-arc]} || die
} else { "${opts[-usrdir]} dir not found" }
mkdir -p {,s}bin usr/{{,s}bin,share/{consolefonts,keymaps},lib${opts[-arc]}} || die
mkdir -p dev proc sys newroot mnt/tok etc/{mkinitramfs-ll{,.d},splash} || die
mkdir -p run lib${opts[-arc]}/{modules/${opts[-kversion]},mkinitramfs-ll} || die
ln -sf lib{${opts[-arc]},} &&
	pushd usr && ln -sf lib{${opts[-arc]},} && popd || die

cp -a /dev/{console,random,urandom,mem,null,tty{,[0-6]},zero} dev/ || adn
if [[ ${${(pws:.:)opts[-kversion]}[1]} -eq 3 ]] &&
	[[ ${${(pws:.:)opts[-kversion]}[2]} -ge 1 ]] {
	cp -a {/,}dev/loop-control 1>/dev/null 2>&1 ||
		mknod -m 600 dev/loop-control c 10 237 || die
}

cp -af ${opts[-workdir]}/init . && chmod 775 init || die

for mod (${(pws,:,)opts[-M]} ${(pws,:,)opts[-module]})
	cp -a ${opts[-usrdir]:h}/mkinitramfs-ll.d/*$mod* etc/mkinitramfs-ll.d/
cp -ar {/,}lib/modules/${opts[-kversion]}/modules.dep ||
	die "failed to copy modules.dep"

[ -f /etc/issue.logo ] && cp {/,}etc/issue.logo

if [[ -x usr/bin/busybox ]] {
	mv -f {usr/,}bin/busybox
} elif [[ $(which busybox) != "busybox not found" ]] &&
	[[ $(ldd $(which busybox)) == *"not a dynamic executable" ]] {
	cp -a $(which busybox) bin/
} elif [[ $(which bb) != "bb not found" ]] {
	cp -a $(which bb) bin/busybox
} else { die "no suitable busybox/bb binary found" }

if [[ ! -f etc/mkinitramfs-ll/busybox.app ]] {
	bin/busybox --list-full >etc/mkinitramfs-ll/busybox.app || die
}
for app ($(< etc/mkinitramfs-ll/busybox.app)) ln -fs /bin/busybox ${app}

if [[ -n ${(k)opts[-L]} ]] || [[ -n ${(k)opts[-luks]} ]] { 
	opts[-bin]+=:cryptsetup opts[-kmodule]+=:dm-crypt
}

if [[ -n ${(k)opts[-gpg]} ]] || [[ -n ${(k)opts[-g]} ]] {
	opts[-kmodule]+=:gpg
	if [[ -x usr/bin/gpg ]] { :;
	} elif [[ $($(which gpg) --version | grep 'gpg (GnuPG)' | cut -c13) = 1 ]] {
		opts[-bin]+=:$(which gpg)
	} else { die "there's no usable gpg/gnupg-1.4.x" }
	if [[ -f root/.gnupg/gpg.conf ]] {
		ln -sf {root/,}.gnupg && chmod 700 root/.gnupg/gpg.conf
	} else { warn "no gpg.conf was found" }
}

if [[ -n ${(k)opts[-lvm]} ]] || [[ -n ${(k)opts[-l]} ]] {
	opts[-bin]+=:lvm:lvm.static opts[-kmodule]+=:device-mapper
	pushd sbin
	for lpv ({vg,pv,lv}{change,create,re{move,name},s{,can}} \
		{lv,vg}reduce lvresize vgmerge) ln -sf lvm ${lpv} || die
	popd
}

if [[ -n ${(k)opts[-sqfsd]} ]] || [[ -n ${(k)opts[-q]} ]] { 
	opts[-bin]+=:mount.aufs:umount.aufs opts[-kmodule]+=:sqfsd
}

# @FUNCTION: domod
# @DESCRIPTION: copy kernel module
domod() {
	local mod module ret
	for mod ($*) {
		module=(/lib/modules/${opts[-kversion]}/**/${mod}.(ko|o))
		if [[ -n ${module} ]] { 
			mkdir -p .${module:h} && cp -ar {,.}${module} ||
				die "failed to copy ${module} module"
		} else {
			warn "${mod} does not exist"
			((ret=${ret}+1))
		}
	}
	return ${ret}
}

for bin (dmraid mdadm zfs) if [[ -n $(echo ${opts[-b]} | grep $bin) ]] ||
	[[ -n $(echo ${opts[-bin]} | grep $bin) ]] { opts[-kmodule]+=:$bin }
opts[-kmodule]=${opts[-kmodule]/mdadm/raid}

for keymap (${(pws,:,)opts[-keymap]} ${(pws,:,)opts[-y]}) {
	if [[ -f usr/share/keymaps/${keymap}-${opts[-arch]}.bin ]] { :;
	} elif [[ -f ${keymap} ]] { cp -a ${keymap} usr/share/keymaps/
	} else { 
		loadkeys -b -u ${keymap} > usr/share/keymaps/${keymap}-${opts[-arch]}.bin ||
			die "failed to build ${keymap} keymap"
	}
}

for font (${(pws,:,)opts[-font]} ${(pws,:,)opts[-f]}) {
	if [[ -f usr/share/consolefonts/${font} ]] { :;
	} elif [[ -f ${font} ]] { cp -a ${font} usr/share/consolefonts/
	} else {
		for file (/usr/share/consolefonts/${font}*.gz) {
			cp ${file} . 
			gzip -d ${file:t}
		}
		mv ${font}* usr/share/consolefonts/
	}
}

if [[ -n ${opts[-splash]} ]] || [[ -n ${opts[-s]} ]] { 
	opts[-bin]+=:splash_util.static:fbcondecor_helper
	
	if [[ -n ${(k)opts[-toi]} ]] || [[ -n ${(k)opts[-t]} ]] {
		opts[-bin]+=:tuxoniceui_text
	}
	
	for theme (${(pws,:,)opts[-splash]} ${(pws,:,)opts[-s]})
		if [[ -d etc/splash/${theme} ]] { :;  
		} elif [[ -d /etc/splash/${theme} ]] { cp -ar {/,}etc/splash/${theme}
		} elif [[ -d ${theme} ]] { cp -r ${theme} etc/splash/ 
		} else { warn "splash themes does not exist" }
}

# @FUNCTION: dobin
# @DESCRIPTION: copy binary with libraries if not static
dobin() {
	for bin ($@)
	if [[ -x ${bin}  ]] { 
		cp -a ${bin} .${bin/%.static}
		if [[ -L ${bin} ]] {
			bin=$(which $(readlink ${bin})) && cp -au {,.}${bin} || die
		}
		if [[ $(ldd ${bin}) != *"not a dynamic executable" ]] {
			for lib ($(ldd ${bin} | tail -n+2 | sed -e 's:li.*=>\ ::g' -e 's:\ (.*)::g'))
			mkdir -p .${lib:h} && cp -adH {,.}${lib} || die 
			warn "${bin} is not a static binary."
		}
	} else { warn "${bin} binary doesn't exist" }
}

for bin (${(pws,:,)opts[-bin]} ${(pws,:,)opts[-b]})
	if [[ -x usr/bin/${bin:t} ]] || [[ -x usr/sbin/${bin:t} ]] ||
		[[ -x bin/${bin:t} ]] || [[ -x sbin/${bin:t} ]] { :;
	} elif [[ -x ${bin} ]] { dobin ${bin}
	} else {
		which ${bin:t} 1>/dev/null 2>&1 && dobin $(which ${bin:t}) ||
		warn "no ${bin} binary found"
	}

for module (${(pws,:,)opts[-mdep]} ${(pws,:,)opts[-m]}) domod ${module}
for grp (${(pws,:,)opts[-kmodule]})
	for mod (${(pws,:,)opts[-m${grp}]})
		domod ${mod} && echo ${mod} >>etc/mkinitramfs-ll/module.${grp}

docpio || die

print -P "%F{green}>>> ${opts[-initramfs]} initramfs built%f"

if [[ -n ${(k)opts[-clean]} ]] || [[ -n ${(k)opts[-n]} ]] {
	rm -rf ${opts[-initdir]}
}

unset opts

# vim:fenc=utf-8ft=zsh:ci:pi:sts=0:sw=4:ts=4:
