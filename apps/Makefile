.PHONY : all clean

COMPFLAGS=

export LUPO_INCLUDEPATH=../include
export LNG_LIBRARIES=../lib/libstd.a

VPATH=../include

# list of applications
APPS=testapp microterm ps lsmod sh wc getty sleep cat tee uuencode uudecode \
     232echo 232term sliptst telnet kill rm ls connd ftp buf cp tcpipstat \
     meminfo strminfo uptime time uname more loop slip ppp tcpip help \
     b-cs b-co env beep httpd clear popclient true false echo

# list of applications that must be linked against libstd
LAPPS=amalloc date ciartc hextype smwrtc dcf77 ide64rtc

all : $(APPS) $(LAPPS)

# Rules
% : %.s ; luna -qWR $< -o $@ $(COMPFLAGS)
%.o : %.s ; luna -qWO $< -o $@ $(COMPFLAGS)

$(LAPPS) : $(LAPPS:%=%.o)
	lld -qN $@.o -o $@

# additional dependencies
$(APPS) : system.h rs232.h jumptab.h stdio.h

$(LAPPS) : system.h rs232.h jumptab.h stdio.h ../lib/libstd.a

clean   : 
	-rm $(APPS) $(LAPPS) $(LAPPS:%=%.o)

