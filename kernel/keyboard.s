		;; keyboard interface

#include <config.h>
		
.global keyb_scan
.global keyb_stat
.global keyb_joy0
.global keyb_joy1

#include MACHINE(keyboard.s)
