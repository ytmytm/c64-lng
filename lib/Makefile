.PHONY : all clean

COMPFLAGS=

export LUPO_INCLUDEPATH=../include
VPATH=../include

# list of applications
PARTS=libc_malloc libc_free libc_remalloc sreadline print_hex8 getopt \
      bcdtohex checkbcd

all : libstd.a

libstd.a : $(PARTS:%=%.o)
	lld -Lo libstd.a $(PARTS:%=%.o)

# Rules
%.o : %.s ; luna -qWO $< -o $@ $(COMPFLAGS)

# additional dependencies
$(PARTS:%=%.o) : lib_conf.h

clean   : 
	-rm $(PARTS:%=%.o) libstd.a
