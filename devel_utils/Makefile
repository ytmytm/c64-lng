.PHONY : all clean

CC=gcc
COMPFLAGS=-O6 -pedantic -ansi -Wall -Wstrict-prototypes -Wshadow -Wmissing-declarations -Wmissing-prototypes -fomit-frame-pointer

# list of applications
APPS=luna lupo lld relate chkobj chklib c64arch

all : $(APPS)

clean :
	-rm $(APPS)

$(APPS) : Makefile

# Rules
% : %.c ; $(CC) $< -o $@ $(COMPFLAGS)
