		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		
		;; print_hex8
		;; prints 8bit-value hexadecimal to stdout

		;; < A=value
		;; > (A,X,Y=XX)

#define _date (Jun 15 1997)
#include <stdio.h>

.global print_hex8

		.byte $0c
		.word print_hex8
hex_tab:
		.text "0123456789abcdef"

print_hex8:
		pha
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		jsr  +
		pla
		bcs  ++
		and  #$0f

	+	tay
		lda  hex_tab,y
		sec
		ldx  #stdout
		jsr  fputc
		bcs  +
		rts

		pla
	+	jmp  lkf_catcherr



