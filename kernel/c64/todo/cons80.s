not finished !!!!

		;; console driver displays 40 of 80 chars
		;; some ANSI compatible escape sequences implemented

#include "system.h"
#include "c64.h"

.global console_init
.global printk

		cursor equ 100
		size_x equ 40
		size_y equ 25

		char_map  equ $400
		color_map equ $d800

	-	rts
		
console_init:
		lda  #8
		ldx  #memid_system_ram
		ldy  #%1000000			; no I/O
		jsr  mpalloc
		bcs  -					; not enough RAM, then exit with error
		sta  scrbuffer			; remember position of allocated RAM

		;; adapt pointer in cons_clear
		ldx  #24
		clc
	-	sta  _pbase-1,x			; self modifying code !
		adc  #1
		dex
		dex
		dex
		bne  -

		;; initialize VIC
		lda  CIA2_PRA
		ora  #3
		sta  CIA2_PRA			; select bank 0
		lda  #0
		sta  VIC_SE				; disable all sprites
		lda  #$9b
		sta  VIC_YSCL
		lda  #$08
		sta  VIC_XSCL
		lda  #$16
		sta  VIC_VSCB

		;; set 'desktop' color
		lda  #0
		sta  VIC_BC				; border color
		lda  #11
		sta  VIC_GC0			; background color

		lda  #$80
		sta  cflag				; cursor enabled (not jet drawn)
		lda  #0
		sta  dmode				; show columns 1..40
		jsr  cons_home
		jsr  cons_pheadline
		jmp  cons_clear

		;; print (update) headline
cons_pheadline:
		ldx  #39
	-	lda  headline_txt,x
		sta  char_map,x
		lda  #15
		sta  color_map
		dex
		bpl  -

		lda  #"*"				; those asciis are equal to the screen codes!
		ldx  dmode
		beq  +
		lda  #"<"
	+	sta  char_map

		lda  #"*"
		ldx  dmode  
		cpx  #2
		beq  +
		lda  #">"
		sta  char_map+39
		rts
		
		;; clear screen
cons_clear:
		jsr  cons_hidecsr
		lda  #5					; text color
		ldx  #0
	-	sta  color_map,x
		sta  color_map+$100,x
		sta  color_map+$200,x
		sta  color_map+$300,x
		inx
		bne  -
		lda  #32
	-	sta  char_map,x
		sta  char_map+$100,x
		sta  char_map+$200,x
		sta  char_map+$300,x
		inx
		bne  -
		;; also clear whole screen buffer
_pbase:
		sta  .0,x				; (scrbuffer+7)*256,x
		sta  .0,x				; (scrbuffer+6)*256,x
		sta  .0,x				; (scrbuffer+5)*256,x
		sta  .0,x				; (scrbuffer+4)*256,x
		sta  .0,x				; (scrbuffer+3)*256,x
		sta  .0,x				; (scrbuffer+2)*256,x
		sta  .0,x				; (scrbuffer+1)*256,x
		sta  .0,x				; (scrbuffer+0)*256,x
		inx
		bne  _pbase
		
		jsr  cons_showcsr
		rts

		;; move cursor to the upper left corner of the screen
cons_home:		
		ldx  #0
		ldy  #0

cons_setpos:
		cpx  #size_x
		bcs  +
		cpy  #size_y
		bcs  +					; ignore invalid settings
		stx  csrx
		sty  csry
		;; calculate position in RAM
		tya
		asl  a
		asl  a
		sta  mapl				; Y*4
		tya
		adc  mapl				; Y*5
		asl  a					; Y*10 (<240)
		asl  a
		sta  mapl
		lda  #0
		rol  a
		asl  mapl
		rol  a					; Y*40
		adc  #>char_map				; start of screen
		sta  maph
		txa
		adc  mapl
		sta  mapl				; Y*40+X
	+	rts

cons_csrup:
		ldx  csry
		beq  err				; error
		dex
		stx  csry
		sec
		lda  mapl
		sbc  #40
		sta  mapl
		bcs  +
		dec  maph
		clc
	+	rts

err:	sec
		rts
		
cons_csrdown:	
		ldx  csry
		cpx  #size_y-1
		beq  err
		inx
		stx  csry
		clc
		lda  mapl
		adc  #40
		sta  mapl
		bcc  +
		inc  maph
		clc
	+	rts

cons_csrleft:
		ldx  csrx
		beq  err				; error
		dex
		stx  csrx
		lda  mapl
		bne  +
		dec  maph
	+	dec  mapl
		clc
		rts

cons_csrright:	
		ldx  csrx
		cpx  #size_x-1
		beq  err
		inx
		stx  csrx
		inc  mapl
		bne  +
		inc  maph
	+	clc
		rts

cons_scroll_up:
		ldx  #0
	-	lda  char_map+$028,x
		sta  char_map,x
		inx
		bne  -
	-	lda  char_map+$128,x
		sta  char_map+$100,x
		inx
		bne  -
	-	lda  char_map+$228,x
		sta  char_map+$200,x
		inx
		bne  -
	-	lda  char_map+$328,x
		sta  char_map+$300,x
		inx
		cpx  #192
		bne  -
		lda  #32
		ldx  #39
	-	sta  char_map+964,x				; delete the last line
		dex
		bpl  -
		rts

cons_showcsr:
		bit  cflag
		bvs  +					; already shown
		bpl  +					; cursor disabled
		sei
		lda  mapl
		sta  tmpzp
		lda  maph
		sta  tmpzp+1
		ldy  #0
		lda  (tmpzp),y
		sta  buc
		lda  #cursor
		sta  (tmpzp),y
		cli
		lda  #$c0
		sta  cflag
	+	rts

cons_hidecsr:
		bit  cflag
		bvc	 +					; no cursor there
		sei
		lda  mapl
		sta  tmpzp
		lda  maph
		sta  tmpzp+1
		ldy  #0
		lda  buc
		sta  (tmpzp),y
		cli
		lda  cflag
		and  #%10111111
		sta  cflag
	+	rts
				
		;; convert ascii to screencodes
cons_a2p:
		cmp  #32
		bcc  _is_special
		cmp  #64
		bcc  _keepit			; <64, then no change
		beq  _is_special
		cmp  #91
		bcc  _keepit			; big letter (no change)
		cmp  #97
		bcc  _is_special		; 91..96
		cmp  #123
		bcc  _sub96				; small letters (-96)
_is_special:
		ldx  #_no_of_specials
	-	cmp  special_mapping-1,x
		beq  +
		dex
		bne  -
		;; not found
		lda  #102
		sec
		rts

	+	lda  special_code-1,x
		.byte $2c
				
_sub96:	
		sbc  #95
_keepit:		
		clc
		rts

special_mapping:
		.byte $40,$7b,$7d,$5c,$7e,$60,$5b,$5d,$a7,$5e,$7c,$5f,$1c,$1e
_no_of_specials equ *-special_mapping

special_code:
		.byte   0,115,107,127,113,109, 27, 29, 92, 30, 93,100, 94, 28
		
printk:
		pha
		sta  cchar
		txa
		pha
		tya
		pha
		
		jsr  cons_hidecsr
		lda  cchar
		cmp  #32
		bcc  special_chars
		jsr  cons_a2p
		tax
		php
		sei
		lda  mapl
		sta  tmpzp
		lda  maph
		sta  tmpzp+1
		ldy  #0
		txa
		sta  (tmpzp),y
		plp
		jsr  cons_csrright
_back:	jsr  cons_showcsr
		
		pla
		tay
		pla
		tax
		pla
		rts

special_chars:

#ifdef petscii		
		cmp  #13
		beq  _crlf
		cmp  #10
		beq  _cr
		jmp  _back
#else
		;; UNIX ascii (default)
		cmp  #10
		beq  _crlf
		cmp  #13
		beq  _cr
		jmp  _back
#endif
				
_crlf:	jsr  cons_csrdown
		bcc  _cr
		jsr  cons_scroll_up
_cr:	ldx  #0
		ldy  csry
		jsr  cons_setpos
		jmp  _back		

mapl:	.byte 0
maph:	.byte 0
csrx:	.byte 0
csry:	.byte 0
buc:	.byte 0					; byte under cursor
cflag:	.byte 0					; cursor flag (on/off)
cchar:	.byte 0

dmode:			.byte 0			; display mode 0=1..41, 1=21..60, 2=41..80 
scrbuffer:		.byte 0			; high byte of screen buffer (8k)

headline_txt:
		.byte 32,45,32,32,32,32,32,32 ; " -      "
		.byte 32,76,85,14,09,24,32,86 ; " LUnix V"
		.byte 56,48,32,03,15,14,19,15 ; "80 conso" 
		.byte 12,05,32,22,48,46,49,32 ; "le v0.1 "
		.byte 32,32,32,32,32,32,45,32 ; "      - "

