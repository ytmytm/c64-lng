		;; cat - v1.0
		;; (c) 1999 Piotr Roszatycki <dexter@fnet.pl>
		
#include <system.h>
#include <kerrors.h>
#include <stdio.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		cat_argv equ userzp
		cat_file equ userzp+2

		lda #3					; allocate 3 bytes of zeropage
		jsr lkf_set_zpsize			; (2 is default)
		
		ldx #stdin				; read from stdin if no argument
		stx cat_file

		lda cat_argv				; get number of arguments submitted
		cmp #1
		beq cat_fread
		cmp #2
		bne cat_help 				; no argument - print help

		;; read file name
		ldy #0
		sty cat_argv				; now (userzp) points to first argument
	-	iny
		lda (cat_argv),y
		bne -					; skip first argument
		iny
		
		tya					; (userzp) -> A/Y
		clc
		adc cat_argv
		ldy cat_argv+1
		bcc +
		iny
	+	sec
		ldx #fmode_ro
		jsr fopen				; open file
		bcc +
		jmp lkf_suicerrout
	+	stx cat_file
		
cat_fread:
		sec
		ldx cat_file
		jsr fgetc
		bcs cat_ferror
			
		sec					 
		ldx #stdout
		jsr fputc
		jmp cat_fread

cat_ferror:	
		cmp #lerr_eof
		beq cat_feof
		jmp lkf_suicerrout
cat_feof:
		ldx userzp+2
		jsr fclose
		lda #$00
		rts						; exit(0)

cat_help:
		ldx #stdout
		bit cat_helptext
		jsr lkf_strout
		nop
		lda #1
		jmp lkf_suicide

		RELO_END ; no more code to relocate
	
cat_helptext:
		.text "Usage: cat [file]"
		.byte $0a,$00
		
end_of_code:
