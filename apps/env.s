		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; print environment settings
		;; there currently are no user definable environment strings
	
#include <system.h>
#include <stdio.h>
#include <kerrors.h>
		
		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION,	<LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code
		
		;; (task is entered here)

		lda  userzp
		cmp  #1
		beq  +
		
		;; print howto message and terminate with error (code 1)
		
		ldx  #stdout
		bit  txt_howto
		jsr  lkf_strout
		lda  #1
		rts
		
	+	ldx  userzp+1			; address of commandline (hi byte)
		jsr  lkf_free			; free used memory

		;; main programm code
		ldx  #stdout
		bit  txt_cwd
		jsr  lkf_strout

		ldy  #tsp_pdmajor
		lda  (lk_tsp),y
		jsr  decout
		lda  #","
		jsr  out
		ldy  #tsp_pdminor
		lda  (lk_tsp),y
		jsr  decout

		ldx  #stdout
		bit  txt_term
		jsr  lkf_strout

		ldy  #tsp_termwx
		lda  (lk_tsp),y
		jsr  decout
		lda  #"x"
		jsr  out
		ldy  #tsp_termwy
		lda  (lk_tsp),y
		jsr  decout

		lda  #$0a
		jsr  out

		lda  #0					; (error code, 0 for "no error")
		rts						; return with no error
		
		;; print decimal number (8bit)
decout:
		ldx  #0
		ldy  #2
	-	sec
	-	sbc  dectab,y
		bcc  +
		inx
		bcs  -
	+	adc  dectab,y
		pha
		txa
		beq  +
		ldx  #"0"
		ora  #"0"
		stx  userzp+2
		jsr  out
		ldx  userzp+2
	+	pla
		dey
		bne  --
		ora  #"0"
out:
		ldx  #stdout
		sec
		jsr  fputc
		nop
		rts		

		RELO_END ; no more code to relocate

		;; help text to print on error
		
txt_howto:
		.text "usage: env",$0a
		.text "  print environment settings",$0a,0

txt_cwd:
		.text "current working device: ",0

txt_term:
		.text $0a,"terminal width: ",0

dectab:	.byte 1,10,100

end_of_code:
