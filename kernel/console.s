		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; simple console driver

#include <config.h>
		
.global	console_toggle

		;; function: printk
		;; < A=char
		;; print (kernel) messages to console directly all registers
		;; (A, X and Y) are unchanged !!
		;; calls: cons_out
.global printk

printk:
		pha
		sta  dirty
		txa
		pha
		tya
		pha
dirty equ *+1
		lda  #0					; (self modifying code)
		ldx  #0		
		jsr  cons_out
		pla
		tay
		pla
		tax
		pla
		rts
		
		;; function: cons_out
		;; < A=char, X=number of console
		;; print character to console
		;; calls: locktsw
		;; calls: untocktsw
		;; changes:	tmpzp(0,1)
.global cons_out

#ifdef VDC_CONSOLE
# include "opt/vdc_console.s"
#else
		;; default is to use VIC for console output
		
# ifdef MULTIPLE_CONSOLES
	
		;; variable reflects which console currently is visible to
		;; the user (keyboad input will go there!) (in zp.h!)
;.global cons_visible
		
		;; console_single is the old (working) version of the
		;; console driver (just to have something to fall back)
#  include "opt/vic_console.s"
# else
#  include "opt/vic_console_single.s"
# endif

#endif
