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

MACHINE=c64

# Modules to include in package (created with "make package")

MODULES=sswiftlink sfifo64 rs232std swiftlink

# Applications to include in package
# the applications (in binary form) do not depend on the machine selection

APPS=getty lsmod microterm ps sh sleep testapp wc cat tee uuencode \
     uudecode 232echo 232term telnet kill rm ls connd ftp buf cp tcpipstat \
     uptime date meminfo strminfo uname more slip tcpip ppp loop

#============== end of configurable section ============================

.PHONY : all package clean kernel apps

export LUPO_INCLUDEPATH=../kernel
export COMPFLAGS
export MACHINE

all : kernel apps

apps :
	make -C apps

kernel :
	make -C kernel

BINDIR=$(patsubst c%,bin%,$(MACHINE))

package : 
	-mkdir $(BINDIR)
	cp -va kernel/boot.$(MACHINE) kernel/lunix.$(MACHINE) \
         $(MODULES:%=kernel/modules/%) $(APPS:%=apps/%) $(BINDIR)
	cd $(BINDIR) ; c64arch lng.$(MACHINE) "*loader" \
         boot.$(MACHINE) lunix.$(MACHINE) $(APPS) $(MODULES)

clean :
	make -C kernel clean
	make -C apps clean

distclean : clean
	-cd kernel ; rm boot.c* lunix.c* globals.txt
	-cd bin64 ; rm $(APPS) $(MODULES) boot.* lunix.* lng.c64
	-cd bin128 ;  rm $(APPS) $(MODULES) boot.* lunix.* lng.c128
	-cd include ; rm ksym.h zp.h
	find . -name "*~" -exec rm -v \{\} \;
	find . -name "#*" -exec rm -v \{\} \;
