PACKAGE = mkinitramfs-ll
VERSION = $(grep Header init | sed -e 's:# $Header.*,v ::' -e 's:2012.*$::')

prefix      = usr/local
bindir      = ${DESTDIR}/${prefix}/sbin
bin_prefix  = mkifs-ll
sys_confdir	= ${DESTDIR}/etc
svc_confdir	= ${sys_confdir}/conf.d
svc_initdir	= ${sys_confdir}/init.d
datadir	    = ${DESTDIR}/${prefix}/share/$(PACKAGE)
docdir      = ${DESTDIR}/${prefix}/share/doc/$(PACKAGE)-${VERSION}

DOCS=AUTHORS COPYING README ChangeLog KnownIssue

all: install_init install_svcsquash install_scripts_bash

install_init
	install -pd $(datadir)
	install -pm 755 init                   $(datadir)

install_scripts_bash:
	sed -e 's:\./${bin_prefix}:${bin_prefix}:g' \
		-e 's:${bin_prefix}.conf:/etc/${bin_prefix}.conf:g' -i ${bin_prefix}*.bash
	install -pd $(sys_confdir)
	install -pd $(bindir)
	install -pm 644 ${bin_prefix}.conf.bash $(sys_confdir)
	install -pm 755 ${bin_prefix}.bash      $(bindir)
	install -pm 755 ${bin_prefix}.bb.bash   $(bindir)
	install -pm 755 ${bin_prefix}.gen.bash  $(bindir)
	install -pm 755 ${bin_prefix}.gpg.bash  $(bindir)
	install -pm 755 sqfsd/sdr.bash          $(bindir)

install_svcsquash:
	install -pd $(svc_confdir)
	install -pd $(svc_initdir)
	install -pm 755 sqfsd/sqfsdmount.initd  $(svc_initdir)/sqfsdmount
	install -pm 644 sqfsd/sqfsdmount.confd  $(svc_confdir)/sqfsdmount

postinstall:

uall: unintsall_init uninstall_scripts_bash  uninstall_svcsquash

uninstall_init:
	rm -f $(datadir)/init

uninstall_scripts_bash:
	rm -f $(bindir)/${bin_prefix}.bash
	rm -f $(bindir)/${bin_prefix}.bb.bash
	rm -f $(bindir)/${bin_prefix}.gen.bash
	rm -f $(bindir)/${bin_prefix}.gpg.bash
	rm -f $(sys_confdir)/${bin_prefix}.conf.bash

uninstall_svcsquash:
	rm -f $(svc_confdir)/sqfsdmount
	rm -f $(svc_initdir)/sqfsdmount

postuninstall: