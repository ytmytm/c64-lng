		;; keyboard interface

#include <config.h>
		
.global keyb_scan
.global keyb_stat
.global keyb_joy0
.global keyb_joy1

#ifdef PCAT_KEYB
# include "opt/pcat_keyboard.s"
#else
# include MACHINE(keyboard.s)
#endif
