		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; ls
		
#include <system.h>
#include <kerrors.h>
#include <stdio.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		lda  userzp					; get number of arguments submitted
		bne  +

HowTo:	
		ldx  #stderr
		bit  howto_txt
		jsr  lkf_strout
		lda  #1
		rts						; exit(1)
		
		;; close stdin channel
	+	ldx  #stdin
		jsr  fclose
		nop
		
		;; parse commandline
		ldy  #0
		sty  userzp				; now (userzp) points to first argument
	-	iny
		lda  (userzp),y
		bne  -					; skip first argument
		iny

	-	lda  (userzp),y
		beq  do_open
		cmp  #"-"
		bne  do_open

		iny
		lda  (userzp),y
		cmp  #"l"				; "l"
		bne  HowTo
		lda  #$80
		sta  long_flag
		iny
		lda  (userzp),y
		bne  HowTo
		iny
		jmp  -
		
		;; print the first filename 4/30/2000 bburns@wso.williams.edu
print_file:
		ldy  #0					; (recall position of filename)
		
	-	lda  (userzp),y
		beq  +					; branch on whitespace
		jsr  out				; print the character
		iny						; move to the next
		bne  -					; (loop exits in any case = good :-)

	+	lda  #$0a				; print the newline.
		jsr  out
		rts		

		;; print the no such file or dir error message.
no_such:	
		ldx  #stderr
		bit  no_such_txt
		jsr  lkf_strout
		jsr	 print_file
		lda  #1
		rts

do_open:
		;; no other args?
		sty  userzp				; now (userzp) points to filename|dirname
		ldy  #0
		lda  (userzp),y
		beq  dir
	-	iny
		lda  (userzp),y
		bne  -
		iny
		lda  (userzp),y			; too many arguments ?
		bne  HowTo				; if so, print howto

		lda  userzp				; Try to open it as a file.
		ldy  userzp+1
		ldx  #fmode_ro			; (open read-only)
		jsr  fopen
		bcc  file
		cmp	 #lerr_nosuchfile	; If that's the reason for failure...
		beq  +
		jmp  lkf_suicerrout
		
		;; open directory
dir:							; Try to open it as a directory.
	+	lda  userzp
		ldy  userzp+1
		jsr  fopendir
		bcc	 +
		cmp	 #lerr_nosuchdir
		beq  no_such
		jmp  lkf_suicerrout

file:	
		jsr  print_file
		lda  #0
		rts
		
		;; read directory entries
	+	bit  dir_struct
loop:
		sec
		lda  #<dir_struct
		ldy	 loop-1				; #>dir_struct
		ldx  #stdin
		jsr  freaddir
		bcs  loop_end

		bit  long_flag
		bmi  long_form

out_finish:
		ldx  #stdout
		bit  dir_struct+12
		jsr  lkf_strout
		nop
		lda  #$0a
		jsr  out
		jmp  loop

loop_end:
		cmp  #lerr_eof
		bne  +
		lda  #0
		rts						; exit(0)

	+	jmp  lkf_suicerrout

long_form:
		jsr  print_perm
		jsr  print_size
		jsr  print_date
		jmp  out_finish
		
print_perm:
		lda  dir_struct
		and  #$01				; perm field valid ?
		bne  +
		ldx  #stdout
		bit  noperm_txt
		jsr  lkf_strout			; (don't replace with jmp!)
		rts
	+	ldx  #"d"				; "d"
		lda  #$80
		jsr  mout
		ldx  #"r"				; "r"
		lda  #$04
		jsr  mout
		ldx  #"w"				; "w"
		lda  #$02
		jsr  mout
		ldx  #"x"				; "x"
		lda  #$01
		jsr  mout
space:
		lda  #" "
		jmp  out

mout:	and  dir_struct+1
		bne  +
		ldx  #"-"
	+	txa
		jmp  out

print_size:
		lda  dir_struct
		and  #$02				; size field valid ?
		bne  +
		ldx  #stdout
		bit  nosize_txt
		jsr  lkf_strout			; (don't replace with jmp!)
		rts
	+	lda  dir_struct+5
		beq  +
		jsr  hexout
	+	lda  dir_struct+4
		jsr  hexout
		lda  dir_struct+3
		jsr  hexout
		lda  dir_struct+2
		jsr  hexout
		jmp  space

print_date:
		lda  dir_struct
		and  #$04
		bne  +
		ldx  #stdout
		bit  nodate_txt
		jsr  lkf_strout			; (don't replace with jmp!)
	+	rts

		
hexout:	
		pha
		lsr  a		
		lsr  a		
		lsr  a		
		lsr  a
		jsr  +
		pla
		and  #$0f
	+	tax
		lda  hextab,x
out:	sec
		ldx  #stdout
		jsr  fputc
		nop
		rts

		.byte $02				; End Of Code - marker !

hextab:	.text "0123456789abcdef"

no_such_txt:	
		.text "No such file or directory: "		
		.byte $00
						
howto_txt:
		.text "Usage: ls [-l] [dir]"
		.byte $0a,$00

noperm_txt:  ;"dwrx " 
		.text ".... ",0

nosize_txt:  ;"112233 " 
		.text "...... ",0

nodate_txt:  ;"30Jun19:28 "
		.text ".......... ",0
		
long_flag:
		.byte 0					; short is default
		
dir_struct:
		.buf DIRSTRUCT_LEN
		
end_of_code:
