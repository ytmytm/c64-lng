		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; simple output application
	
#include <system.h>
#include <stdio.h>
#include <kerrors.h>
#include <cstyle.h>
#include <ident.h>
				
		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION,	<LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code
		
		;; (task is entered here)
		
		jsr  parse_commandline
		
		ldx  userzp+1			; address of commandline (hi byte)
		jsr  lkf_free			; free used memory
								; (commandline not needed any more)

		jmp  main_code
		

		;; print howto message and terminate with error (code 1)
		
howto:	ldx  #stdout
		bit  txt_howto
		jsr  lkf_strout
		exit(1)					; (exit() is a macro defined in
								;  include/cstyle.h)

		;; commandline
		;;  first argument is the command name itself
		;;  so userzp (argc = argument count) is at least 1
		;;  userzp+1 holds the hi-byte of the argument strings address

		;; format of the argument string:
		;;  "<command-name>",0,"<argument1>",0,...,"<last argument>",0 ,0
		
parse_commandline:
		;; check for correct number of arguments
		lda  userzp				; (number of given arguments)
		beq  +					; (ok)
		
		cmp  #1					; need exactly NONE arguments
		bne  howto				; (if argc != 2 goto howto)

	+	rts

		;; main programm code
main_code:
		set_zeropage_size(0)	; tell the system how many zeropage
								; bytes we need
								; (set_zeropage_size() is a macro defined
								; in include/cstyle.h) 

		lda  #27				; ANSI codes for "clear" & "home"
		sec
		ldx  #stdout
		jsr  fputc
		lda  #"["
		sec
		ldx  #stdout
		jsr  fputc
		lda  #"2"
		sec
		ldx  #stdout
		jsr  fputc
		lda  #"J"
		sec
		ldx  #stdout
		jsr  fputc

		lda  #27
		sec
		ldx  #stdout
		jsr  fputc
		lda  #"["
		sec
		ldx  #stdout
		jsr  fputc
		lda  #"H"
		sec
		ldx  #stdout
		jsr  fputc

		exit(0)
		
		.endofcode
		ident(clear,2.0)

		;; help text to print on error
		
txt_howto:
		.text "Usage: clear",$0a
		.text "  used like CLR key",$0a,0
		
end_of_code:
