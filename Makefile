# compile switches:
# =================
#  look into the machine specific config.h for details on compile switches.
#  (eg. kernel/c64/config.h)

COMPFLAGS=

# selection of target machine
# ===========================
#
# MACHINE=c64 to create Commodore64 version (binaries in bin64)
# MACHINE=c128 for Commodore128 version (binaries in bin128)
# MACHINE=atari for Atari 65XE/800/130 version (no binaries right now)

MACHINE=c64

# Modules to include in package (created with "make package")

MODULES=sswiftlink sfifo64 rs232std swiftlink fifo64

# Applications to include in package
# the applications (in binary form) do not depend on the machine selection

APPS=getty lsmod microterm ps sh sleep testapp wc cat tee uuencode \
     uudecode 232echo 232term kill rm ls buf cp uptime time meminfo \
     strminfo uname more beep help env date ciartc dcf77 smwrtc \
     hextype clear true false echo touch \
     b-co b-cs ide64rtc cd

# Internet Applications
# will be put in the same package als APPS now, but may go into a
# seperate one, in case the APP-package grows to big

IAPPS=connd ftp tcpipstat tcpip ppp loop slip httpd telnet popclient

#============== end of configurable section ============================

.PHONY : all apps kernel libstd help package clean distclean devel

export PATH+=:$(PWD)/devel_utils/:.
export LUPO_INCLUDEPATH=../kernel
export COMPFLAGS
export MACHINE

all : kernel libstd apps help

apps : libstd
	$(MAKE) -C apps

kernel :
	$(MAKE) -C kernel

libstd :
	$(MAKE) -C lib

help :
	$(MAKE) -C help

devel :
	$(MAKE) -C devel_utils

BINDIR=$(patsubst c%,bin%,$(MACHINE))

package : 
	-mkdir $(BINDIR) pkg
	cp kernel/boot.$(MACHINE) kernel/lunix.$(MACHINE) $(MODULES:%=kernel/modules/%) $(BINDIR)
	cd $(BINDIR) ; mksfxpkg $(MACHINE) ../pkg/core.$(MACHINE) \
         "*loader" boot.$(MACHINE) lunix.$(MACHINE) $(MODULES)
	cd apps ; mksfxpkg $(MACHINE) ../pkg/apps.$(MACHINE) $(APPS) $(IAPPS)
	cd help ; mksfxpkg $(MACHINE) ../pkg/help.$(MACHINE) *.html

clean :
	$(MAKE) -C kernel clean
	$(MAKE) -C apps clean
	$(MAKE) -C lib clean
	$(MAKE) -C help clean

distclean : clean
	-cd kernel ; rm boot.c* lunix.c* globals.txt
	-cd bin64 ; rm $(MODULES) boot.* lunix.* lng.c64
	-cd bin128 ;  rm $(MODULES) boot.* lunix.* lng.c128
	-cd include ; rm jumptab.h jumptab.ca65.h ksym.h zp.h
	-rm -rf pkg
	find . -name "*~" -exec rm -v \{\} \;
	find . -name "#*" -exec rm -v \{\} \;
