
		;; PC compatible AT keyboard driver
		;; (see README.pcatkeyboard for info about building interface)
		;;
		;; based on code/documents by
		;; Jim Rosemary, Ilker Ficicilar and Daniel Dallmann
		;;
		;; by Maciej 'YTM/Alliance' Witkowiak <ytm@friko.onet.pl>
		;; 11-13.02.2000, 22.12.2000

;TODO
;- someone should test it on a SCPU, 2MHz clock works better than 1MHz one, but
;  20MHz might be a difference
;- find more reliable way for scanning keyboard on a c64 (best would be on borders,
;  but I don't want IRQ to waste time waiting for it), using keyboard (FLAG1) as a
;  source of IRQ seems to be bad solution too (random losts?)
;- my 2nd PC keyboard has 3 more extended keys: power, sleep, wake (2 new scancodes) for APM
;  do something with them? how many of the PC keyboards have such features?

#include <config.h>
#include <system.h>
#include MACHINE_H
#include <keyboard.h>
#include <zp.h>

#define	EXT_KEY		$e0		; code for extended scancodes
#define KEY_RELEASED	$f0		; next scancode is for released key

; .extern hook_irq
; .extern printk
; .extern panic

; codes $80-$84, $f0-f2 are internally used by console driver
; codes $e0-$ef are reserved for use by keyboard driver for altflags
;	(although not used here, C64/128 keyboard driver needs them)

#define dunno $7f
#define f1_c            $f1	;  internal code! -> switch to console 1
#define f2_c            dunno
#define f3_c            $f2	;  internal code! -> switch to console 2 (..7)
#define f4_c            dunno
#define f5_c            dunno
#define f6_c            dunno
#define f7_c            dunno
#define f8_c            dunno
#define f9_c		dunno
#define f10_c		dunno
#define f11_c		dunno
#define f12_c		dunno
#define home_c		dunno
#define arrow_left_c	$1b     ;  arrow_left = escape
#define arrow_up_c	$5e	;  arrow up = ^
#define csr_up_c	$81	;  internal codes! -> ESC[A
#define csr_down_c	$82	;  internal codes! -> ESC[B
#define csr_left_c	$84	;  internal codes! -> ESC[D
#define csr_right_c	$83	;  internal codes! -> ESC[C
#define sdel_c		dunno
#define shome_c		dunno

;//#define sarrow_up_c     $1c     ; shift + arrow_up = pi

#define tab_c		$09
#define esc_c		$1b	; esc is truly ESC
#define lf_c		$0a	; linefeed is LF and life is life
#define cr_c		$0a	; enter is also LF

#define backslash_c	$5c
#define rqout_c		$60	; ` (reverse quote) scancode $0e
#define backspace_c	8
#define sbackspace_c	dunno
#define delete_c	8
#define end_c		$03	; CTRL+c, well, end - this way or another
#define insert_c	dunno
#define pageup_c	$f0	; internal code! -> toggle consoles
#define pagedown_c	$f0	; internal code! -> toggle consoles

#define stab_c		tab_c	; something opposite to tab...
#define sspc_c          $20     ; shift + space = space
#define sminus_c	$5f	; shift + "-" = _
#define srquot_c	$7e	; shift + "`" = ~
#define none_c		dunno	; unused scancode
#define slblpar_c	$7b	; shift + "[" = {
#define srblpar_c	$7d	; shift + "]" = }
#define sbackslash_c	$7c	; shift + "\" = |

; all dunnos are modifier keys, all none_c are unused scancodes
; $60 in pos. $0e is rquot_c, but this fails for unknown reason

_keytab_normal:

		.byte none_c, f9_c, none_c, f5_c, f3_c, f1_c, f2_c, f12_c
		.byte none_c, f10_c, f8_c, f6_c, f4_c, tab_c, $60, none_c
		.byte none_c, dunno, dunno, none_c, dunno, $71, $31, none_c
		.byte none_c, none_c, $7a, $73,	$61, $77, $32, none_c
		.byte none_c, $63, $78, $64, $65, $34, $33, none_c
		.byte none_c, $20, $76, $66, $74, $72, $35, none_c
		.byte none_c, $6e, $62, $68, $67, $79, $36, none_c
		.byte none_c, none_c, $6d, $6a, $75, $37, $38, none_c
		.byte none_c, $2c, $6b, $69, $6f, $30, $39, none_c
		.byte none_c, $2e, $2f, $6c, $3b, $70, $2d, none_c
		.byte none_c, none_c, $27, none_c, $5b, $3d, none_c, none_c
		.byte dunno, dunno, cr_c, $5d, none_c, backslash_c, none_c, none_c
		.byte none_c, none_c, none_c, none_c, none_c, none_c, backspace_c, none_c
		.byte none_c, $31, none_c, $34, $37, none_c, none_c, none_c
		.byte $30, $2e, $32, $35, $36, $38, esc_c, dunno
		.byte f11_c, $2b, $33, $2d, $2a, $39, dunno, none_c

_keytab_shift:

		.byte none_c, f9_c, none_c, f5_c, f3_c, f1_c, f2_c, f12_c
		.byte none_c, f10_c, f8_c, f6_c, f4_c, stab_c, srquot_c, none_c
		.byte none_c, dunno, dunno, none_c, dunno, $51, "!", none_c
		.byte none_c, none_c, $5a, $53,	$41, $57, "@", none_c
		.byte none_c, $43, $58, $44, $45, "$", "#", none_c
		.byte none_c, sspc_c, $56, $46, $54, $52, "%", none_c
		.byte none_c, $4e, $42, $48, $47, $59, "^", none_c
		.byte none_c, none_c, $4d, $4a, $55, "&", "*", none_c
		.byte none_c, "<", $4b, $49, $4f, ")", "(", none_c
		.byte none_c, ">", "?", $4c, ":", $50, sminus_c, none_c
		.byte none_c, none_c, $22, none_c, slblpar_c, "+", none_c, none_c
		.byte dunno, dunno, cr_c, srblpar_c, none_c, sbackslash_c, none_c, none_c
		.byte none_c, none_c, none_c, none_c, none_c, none_c, sbackspace_c, none_c
		.byte none_c, "1", none_c, "4", "7", none_c, none_c, none_c
		.byte "0", ".", "2", "5", "6", "8", esc_c, none_c
		.byte f11_c, "+", "3", "-", "*", "9", dunno, none_c


; there are only a few extended keys, so they are evaluted by table with scancodes

_extkey_scan:	.byte $4a, $5a, $69, $6b, $6c, $70	; 13 total
		.byte $71, $72, $74, $75, $7a, $7d
		.byte $7e				; scroll lock

_extkey_tab:	.byte $2f, cr_c, end_c, csr_left_c, home_c, insert_c
		.byte delete_c, csr_down_c, csr_right_c, csr_up_c, pagedown_c, pageup_c
		.byte dunno

; this lookup table is used to resolve modifier and lockable keys

_alts_scancodes:
		.byte $14, $12, $59, $58	; ctrl, rshift, lshift, caps
		.byte $11, $7e, $77, $77	; alt, scrolllock, numlock, numlock
_alts_altflags:
		.byte keyb_ctrl, keyb_rshift, keyb_lshift, keyb_caps
		.byte keyb_alt, keyb_ex1, keyb_ex2, keyb_ex3
_alts_locktab:
		.byte 0, 0, 0, 1		; shifts and controls are modifiers and rest
		.byte 1, 1, 1, 1		; is lockable (=ignore release, toggle on press)

;;; ZEROpage: altflags 1
;;; ZEROpage: keycode 1

ljoy0:			.byte $ff		; last state of joy0
ljoy1:			.byte $ff		; last state of joy1

joy0result:		.byte $ff		; current state of joy0
joy1result:		.byte $ff		; current state of joy1

;altflags:		.buf 1			; altflags (equal to $28d in C64 ROM)
;keycode:		.buf 1			; keycode (equal to $cb in C64 ROM)

		;; interrupt routine, that scans for keys and tests joysticks
		;; (exit via RTS)

keyb_scan:
		lda  #$ff
		sta  port_row			; make sure all lines are high  
		lda  port_row
		and  port_col
		cmp  #$ff			; joystick ??
		beq +
		jsr joys_scan

		lda  ljoy0
		sta  joy0result
		lda  ljoy1
		sta  joy1result
		lda  #$ff
		sta  ljoy0
		sta  ljoy1

		;; keyboard is processed here

	+	jsr keyb_atscanner		; do scan
		bne +				; is there antything?
	-	rts				; no - exit

	+					; yes - process data
		cmp #EXT_KEY
		bne +				; was it extended key set?
		jmp keyb_proc_ext
	+
		cmp #KEY_RELEASED		; was sth pressed or released?
		bne +
		jmp keyb_clear_altflag		; check modifiers

	+	cmp #$83			; f7 is $83 :-(
		bne +
		lda #f7_c
		bne _addkey

	+	lda keycode
		bmi -				; is it normal scancode?	

		jsr keyb_set_altflag
		beq keyb_queuekey		; not modifier		
	-	rts

keyb_proc_ext:
		jsr keyb_atgetbyte		; get 2nd extended code
		cmp #KEY_RELEASED
		bne +
		jmp keyb_clear_altflag		; modifier released?

	+	jsr keyb_set_altflag		; modifier pressed?
		bne -

		;;  should check for those f**king extra-extended
		;;  codes (print screen, pause)

		ldx #0
		lda keycode
	-	cmp _extkey_scan,x
		beq +
		inx
		cpx #13
		bne - 
		rts

	+	lda _extkey_tab,x
		jmp _addkey

keyb_queuekey:
		; queue key into keybuffer
	+	ldx  keycode
		lda  altflags
		tay
		and  #keyb_lshift | keyb_rshift
		bne  +++
		tya
		and  #keyb_ctrl
		bne  +
		tya
		and  #keyb_caps
		bne  ++
		lda  _keytab_normal,x
		jmp  _addkey

	+	lda  _keytab_normal,x	; keytab_ctrl ? (not yet)
		and  #$1f
		jmp  _addkey

	+	lda  _keytab_normal,x	; CAPS
		cmp  #$61		; if >='a'
		bcc  _addkey
		cmp  #$7b		; and =<'z'+1
		bcs  _addkey
		and  #%11011111		; lower->UPPER
		jmp  _addkey

	+	lda  _keytab_shift,x

		;; adds a keycode to the keyboard buffer
		;; (has to expand csr-movement to esacape codes)

_addkey:
		cmp  #$80
		bcc  +
		cmp  #$f0
		bcs  to_toggle_console
		cmp  #$85				; $81/$82/$83/$84 - csr codes
		bcs  +
		;; generate 3byte escape sequence
		pha
		lda  #$1b
		jsr  console_passkey		; (console_passkey is define in fs_cons.s)
		lda  #$5b
		jsr  console_passkey
		pla
		eor  #$c0			; $8x becomes $4x
	+ 	jmp  console_passkey		; pass ascii code to console driver

to_toggle_console:
		and  #$07
		jmp  console_toggle		; call function of console driver
						; (console_toggle is defined is console.s)

		;; PC AT compatible keyboard scanner begins here
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		;; use this when keyboard have to send something now
keyb_atgetbyte:
	-	jsr keyb_atscanner
		beq -
		rts

		;; scanner returns 0 when nothing was pressed
keyb_atscanner:
		lda #0				; 0 means 'nokeys'
		sta keycode

		lda 0				; allow keyboard to send data
		and #%11100111
		sta 0

		lda VIC_RC
		clc
		adc #$28			; set timeout to ~0.0025s
		tay
		lda #%00011000
	-	cpy VIC_RC
		beq +				; timeout reached
		bit 1				; wait for start bit
		bne -
		lda #%00001000
	-	bit 1
		beq -
		lda CIA1_ICR			; clear any pending clock ticks

		ldy #9
	-	lda CIA1_ICR			; assuming that only keyboard will affect it
		beq -
		lda 1				; get one bit
		and #%00010000
		cmp #%00010000
		ror keycode
		lda #8
	-	bit 1				; wait for clock being H again
		beq -
		dey
		bne --

		rol keycode
	-	lda CIA1_ICR			; wait for stop bit
		beq -
		lda #8
	-	bit 1
		beq -

	+	lda 1
		and #%11100111
		ora #%00010000
		sta 1
		lda 0				; prevent keyboard from sending data
		ora #%00011000			; until next scan
		sta 0

		lda keycode
		rts

		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;; other functions
		;; sets bitmask for altkeys

keyb_set_altflag:
		jsr keyb_find_altflag		; is it modifier?
		beq +				; no - it's normal key
		sta keycode
		tya
		bne ++				; it's a lock key - toggle it
		lda altflags
		ora keycode
		sta altflags
	+	rts
	+	lda altflags
		eor keycode
		sta altflags
		tya				; must be non-0 on exit
		rts

keyb_clear_altflag:
		jsr keyb_get_altflag		; get next scancode (after KEY_RELEASED)
		eor #$ff			; invert pattern
		sta keycode
		tya
		bne +				; it was 'lock' key, ignore release
		lda altflags
		and keycode			; clear altflags
		sta altflags
	+	rts

keyb_get_altflag:
		jsr keyb_atgetbyte		; get next scancode
keyb_find_altflag:
		ldx #0
	-	cmp _alts_scancodes,x
		beq +
		inx
		cpx #8
		bne - 
		lda #0
		rts
	+	lda _alts_locktab,x
		tay
		lda _alts_altflags,x
		rts

		;; scan joysticks
joys_scan:
	-	lda  port_row
		cmp  port_row
		bne  -
		tax
		and  ljoy0
		sta  joy0result
		stx  ljoy0
	-	lda  port_col
		cmp  port_col
		bne  -
		tax
		and  ljoy1
		sta  joy1result
		stx  ljoy1
		rts

		;; get state of keyboard
keyb_stat: 
		lda  altflags			; bit2..0= CTRL,right_SHIFT,left_SHIFT
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

