# list of modules
MODULES=sswiftlink sfifo64 rs232std swiftlink fifo64

#============== end of configurable section ============================

.PHONY : all modules clean maintainer-clean

export LUPO_INCLUDEPATH=../include
VPATH=../include

KINCLUDES=config.h system.h kerrors.h ikernel.h \
         keyboard.h debug.h zp.h

BINCLUDES=jumptab.h config.h system.h kerrors.h \
         ikernel.h keyboard.h debug.h ksym.h zp.h

KERNEL=lunix.$(MACHINE)
BOOT=boot.$(MACHINE)

# list of objects (for "lunix.*")
OBJ=init.o delay.o hook.o keyboard.o lock.o panic.o \
    schedule.o sleep.o suspend.o tasksw.o nmi.o console.o error.o \
    imemory.o addtask.o taskctrl.o signal.o smb.o \
    fs.o fs_pipe.o fs_iec.o fs_ide64.o fs_cons.o fs_user.o fs_sys.o \
    reloc.o execute.o module.o o65.o misc.o environment.o

# bootloader objects (for "boot.*")
BOOTOBJ=bootstrap.o calib.o

all : $(KERNEL) $(BOOT) modules

# Rules
%.o : %.s ; luna -Oq $< -o $@ $(COMPFLAGS)
% : %.s ; luna -Rq $< -o $@ $(COMPFLAGS)

# additional dependencies
$(OBJ) : $(MACHINE).h $(KINCLUDES) Makefile
$(BOOTOBJ) : $(MACHINE).h $(BINCLUDES) Makefile
$(patsubst %,modules/%,$(MODULES)) : system.h stdio.h jumptab.h
reloc.o : kfunc_tab.s
#console.o : $(MACHINE)/console.s
#keyboard.o : $(MACHINE)/keyboard.s
#bootstrap.o : $(MACHINE)/console_init.s $(MACHINE)/keyboard_init.s

# copy configuration file
../include/config.h : $(MACHINE)/config.h
	cp $(MACHINE)/config.h ../include

# jumptab header file
../include/jumptab.h : kfunc_tab.s
	mkjumptab_h

#zp.h : $(OBJ:o=s) ../include/config.h
#the above would be correct but would trigger a total rebuild on every
#small code change
../include/zp.h : ../include/config.h
	mkzp_h $(OBJ:o=s)

# final step of creating the kernel (linking all objects)
$(KERNEL) : $(OBJ)
	lld -d globals.txt -o $@ -s 8192 $^

# collect kernel symbols (needed in boot loader)
../include/ksym.h : $(KERNEL) globals.txt
	mksym

# final step of creating the boot loader (linking all objects)

ifeq "$(MACHINE)" "c64"
 START_ADDRESS=4096
endif
ifeq "$(MACHINE)" "c128"
 START_ADDRESS=4864
endif
ifeq "$(MACHINE)" "atari"
 START_ADDRESS=20480
endif

$(BOOT) : $(BOOTOBJ)
	lld -o $@ -s $(START_ADDRESS) $^

modules : $(patsubst %,modules/%,$(MODULES))

clean   : 
	-rm *.o $(patsubst %,modules/%,$(MODULES)) ../include/config.h

maintainer-clean : clean
	-rm ../include/zp.h ../include/jumptab.h lunix.c* boot.c* \
            globals.txt ../include/ksym.h

