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

		;; get state of keyboard
keyb_stat:
		lda  altflags				; bit2..0= CTRL,right_SHIFT,left_SHIFT
		rts

		;; get state of joystick 0
keyb_joy0:
		lda  joy0result
		eor  #$ff
		rts

		;; get state of joystick 1
keyb_joy1:
		lda  joy1result
		eor  #$ff
		rts
