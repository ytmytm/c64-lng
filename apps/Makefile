.PHONY : all clean

COMPFLAGS=

export LUPO_INCLUDEPATH=../include
VPATH=../include

# list of applications
APPS=testapp microterm ps lsmod sh wc getty sleep cat tee uuencode uudecode \
     232echo 232term sliptst telnet kill rm ls connd ftp buf cp tcpipstat \
     meminfo strminfo uptime date uname more loop slip ppp tcpip

all : $(APPS)

# Rules
% : %.s ; luna -qR $< -o $@ $(COMPFLAGS)

# additional dependencies
$(APPS) : system.h rs232.h jumptab.h stdio.h

clean   : 
	-rm $(APPS)
