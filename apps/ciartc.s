;   ciartc - Date and time functions for the cia1 real time clock
;   Copyright (C) 2000 Alexander Bluhm
;
;   This program is free software; you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation; either version 2 of the License, or
;   (at your option) any later version.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License
;   along with this program; if not, write to the Free Software
;   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
;

; Alexander Bluhm <mam96ehy@studserv.uni-leipzig.de>

; This module provides a date and time interface. The time is stored in
; the cia1 time of day register. The alarm register is used to periodically
; update the date. The alarm handler is called twice a day, and 
; at 12:00am the date is incremented. The same checks are performed
; on any time read operation, to ensure that the date is correct.
; The hour format is converted from 01-12am/pm to 00-23. Every access
; to this interface has to be in 00-23 format.
; Using the weekday is independent and optional. It is simply incremented
; every day and reset on Monday. Monday is 1 and Sunday 7. 0 is not changed.
; The timezone is just stored and never changed. It can be used to convert
; this format to unix time.

#include <system.h>
#include <jumptab.h>
#include <stdio.h>
#include <kerrors.h>
#include <config.h>
#include MACHINE_H

start_of_code:
		.byte >LNG_MAGIC, <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.word 0

		jmp  initialize

;;; data -------------------------------------------------------------------

		.byte $0c
		.word + 

date:
weekday:	.byte	0	; range from 00 to 07, 00 means invalid
century:	.byte	0	; range form 00 to 99
year:		.byte	0	; range form 00 to 99
month:		.byte	1	; range form 01 to 12
day:		.byte	1	; range form 01 to 31
time:
hour:		.byte	0	; range from 00 to 23
minute:		.byte	0	; range from 00 to 59
second:		.byte	0	; range from 00 to 59
sec10:		.byte	0	; range from 00 to 09
end_of_time:
zonehour:	.byte	0	; range from 00 to 15, bit 7 sign, dst included
zonemin:	.byte	0	; range from 00 to 59, timezone can be 30 min
end_of_date:

ampmhour:	.byte	1	; range from 01 to 12, bit 7 am/pm

daymonth:	.byte	$00,$32,$29,$32,$31,$32,$31,$32,$32,$31,$32,$31,$32
			;   jan feb mar apr may jun jul aug sep oct nov dec

module_struct:
		.asc "rtc"	; module identifier
		.byte 5		; module interface size
		.byte 1		; module interface version number
		.byte 1		; weight (number of available virtual devices)
		.word 0000	; (reserved, used by kernel)
	
		;; functions provided by low-level serial driver
		;;  rtc_lock
		;;  rtc_time_read
		;;  rtc_time_write
		;;  rtc_date_read
		;;  rtc_date_write

	+	jmp rtc_lock
		jmp rtc_time_read
		jmp rtc_time_write
		jmp rtc_date_read
		jmp rtc_date_write
		jmp rtc_raw_write
		
		
;;; alert handler ----------------------------------------------------------

		bit	alert_handler
alert_handler:
		jsr	update_date
		;; the problem is that the kernel alarm handler disables 
		;; cia1 alarms after this routine is called.
		;; we change the return address to avoid this.
		;; this is a DIRTY HACK specific for lunix 0.18 on c64
		;; FIXME: the clean way would be to change the kernel and 
		;; allow to turn off this feature.
		tsx
		inx
		lda	$0100,x
		clc
		adc	#$05		; bypass 5 bytes of instructions
		sta	$0100,x
		inx
		lda	$0100,x
		adc	#$00
		sta	$0100,x
		rts

;;; utilities --------------------------------------------------------------

	;; update_date
	;; read time from cia 
	;; write alarm to cia and increment date if neccessary
	;; irq must be disabled

update_date:
		;; copy cia_tod to time
		lda	CIA1_TODHR
		sta	hour
		ldx	CIA1_TODMIN
		stx	minute
		ldx	CIA1_TODSEC
		stx	second
		ldx	CIA1_TOD10
		stx	sec10
		;; convert am/pm to 00-23
		and	#$7f
		cmp	#$12
		bne	+
		lda	#$00
	+	ldy	hour
		bpl	+
		sed
		clc
		adc	#$12
		cld
	+	sta	hour
		tya
		eor	ampmhour	; has am/pm flag changed
		sty	ampmhour
		bpl	return		; if no, return
		;; set alarm to next hour==12, at least 1 hour from actual time
		tya
		and	#$80
		ora	#$12
		eor	#$80
		tax
		lda	CIA1_CRB
		ora	#$80		; alarm write mode
		sta	CIA1_CRB
		stx	CIA1_TODHR
		ldx	minute
		stx	CIA1_TODMIN
		ldx	second
		stx	CIA1_TODSEC
		ldx	sec10
		stx	CIA1_TOD10
		and	#$7f		; time write mode
		sta	CIA1_CRB
		tya			; is am/pm flag set
		bmi	return		; if yes, return
		;; increment date
		ldy	weekday
		beq	++		; 0 is invalid, don't change
		iny			; increment weekday
		cpy	#8
		bcc	+
		ldy	#1
	+	sty	weekday
	+	sed
		lda	month
		jsr	bcdtohex
		tay			; move hexadecimal month to Y
		lda	day		
		clc
		adc	#$01		; increment day
		sta	day
		cmp	daymonth,y	; is day >= days+1 of this month
		bcc	endincdate	; if no, write hour=0 back to cia
		cpy	#2		; is february ?
		bne	monthover	; if no, leap year is irrelevant
		cmp	#$30		; is day >= 30
		bcs	monthover	; if yes, leap year is irrelevant
		;; month==2, date==29, so check for leap year
		lda	year		; is year equal 0 ?
		bne	year4leap	; if not, leap year equiv to year%4==0
		lda	century
		jsr	bcdtohex
		and	#$03		; is century%4 equal 0 ?
		bne	monthover	; if no, it's not a leap year
		beq	endincdate	; if yes, it's a leap year
return:		clc			; only for jump in
		rts
year4leap:	jsr	bcdtohex
		and	#$03		; is year%4 equal 0 ?
		beq	endincdate	; if yes, it's a leap year
monthover:	ldx	#$01		; we have an overflow in days
		stx	day		; so set day to 01
		;; increment month
		lda	month
		clc
		adc	#$01		; increment month
		sta	month
		cmp	#$13
		bcc	endincdate	; month < 13
		stx	month
		;; increment year and century
		lda	year
		adc	#$00		; carry always set
		sta	year
		lda	century 
		adc	#$00		; carry depends on year overflow
		sta	century
endincdate:	cld			; carry is only set on century overflow
		rts


	;; write_time
	;; write time and alarm to cia
	;; irq must be disabled

write_time:
		;; convert 0-23 to 1-12 am/pm
		lda	hour
		tax
		cmp	#$12
		bcc	+
		sed
		sec
		sbc	#$12
		cld
		tax
		ora	#$80
	+	tay
		cpx	#$00
		bne	+
		tya
		ora	#$12
		tay
		eor	#$80	; cia inverts am/pm on write when hour==12
	+	sty	ampmhour	
		;; write hour to cia
		sta	CIA1_TODHR	; stop clock
		;; set alarm to next 12:00:00:00
		tya
		and	#$80
		ora	#$12
		eor	#$80
		tax
		lda	CIA1_CRB
		ora	#$80		; alarm write mode
		sta	CIA1_CRB
		stx	CIA1_TODHR
		ldx	#$00
		stx	CIA1_TODMIN
		stx	CIA1_TODSEC
		stx	CIA1_TOD10
		and	#$7f		; time write mode
		sta	CIA1_CRB
		;; write rest of time to cia
		ldx	minute
		stx	CIA1_TODMIN
		ldx	second
		stx	CIA1_TODSEC
		ldx	sec10
		stx	CIA1_TOD10	; continue clock
		rts


;;; api --------------------------------------------------------------------

	;; rtc api: rtc_lock
	;; activate cia alarm
	;; < A device number
	;; > c=1 error

rtc_lock:
		clc
		rts

	;; rtc api: rtc_time_read
	;; read time from CIA1
	;; < X/Y address of storage to be filled with time
	;; > c=1 error

rtc_time_read:
		sei
		stx	syszp
		sty	syszp+1
		jsr	update_date
		ldy	#end_of_time-time-1
	-	lda	time,y
		sta	(syszp),y
		dey
		bpl	-
		cli
		clc
		rts


	;; rtc api: rtc_time_write
	;; write time to CIA1
	;; < X/Y address of storage filled with time
	;; > c=1 error

rtc_time_write:
		sei
		stx	syszp
		ldx	lk_ipid
		lda	lk_tstatus,x
		ora	#tstatus_szu
		sta	lk_tstatus,x
		cli
		sty	syszp+1
		;; check syntax of argument
		ldy	#end_of_time-time-1
		lda	(syszp),y	; sec10
		jsr	checkbcd
		bcs	jmperr0
		cmp	#$10
		bcs	illarg0
		dey
	-	lda	(syszp),y	; second + minute
		jsr	checkbcd
		bcs	jmperr0
		cmp	#$60
		bcs	illarg0
		dey
		bne	-
		lda	(syszp),y	; hour
		jsr	checkbcd
		bcs	jmperr0
		cmp	#$24
		bcs	illarg0
		;; copy argument to time
		sei
		ldy	#end_of_time-time-1
	-	lda	(syszp),y
		sta	time,y
		dey
		bpl	-
		jsr	write_time
		ldx	lk_ipid
		lda	lk_tstatus,x
		and	#~(tstatus_szu)
		sta	lk_tstatus,x
		cli
		clc
		rts

illarg0:	lda	#lerr_illarg
jmperr0:	jmp	lkf_catcherr


	;; rtc api: rtc_date_read
	;; read date and time from CIA1
	;; < X/Y address of storage to be filled with date
	;; > c=1 error

rtc_date_read:
		sei
		stx	syszp
		sty	syszp+1
		jsr	update_date
		ldy	#end_of_date-date-1
	-	lda	date,y
		sta	(syszp),y
		dey
		bpl	-
		cli
		clc
		rts


	;; rtc api: rtc_time_date
	;; write date and time to CIA1
	;; < X/Y address of storage filled with date
	;; > c=1 error

rtc_date_write:
		sei
		stx	syszp
		ldx	lk_ipid
		lda	lk_tstatus,x
		ora	#tstatus_szu
		sta	lk_tstatus,x
		cli
		sty	syszp+1
		;; check syntax of argument
		ldy	#end_of_date-date-1
		lda	(syszp),y	; zonemin
		jsr	checkbcd
		bcs	jmperr0
		cmp	#$60
		bcs	illarg0
		dey
		lda	(syszp),y	; zonehour
		and	#$7f
		jsr	checkbcd
		bcs	jmperr0
		cmp	#$16		; value contains DST and even more
		bcs	illarg0
		dey
		lda	(syszp),y	; sec10
		jsr	checkbcd
		bcs	jmperr0
		cmp	#$10
		bcs	illarg0
		dey
		lda	(syszp),y	; second
		jsr	checkbcd
		bcs	jmperr1
		cmp	#$60
		bcs	illarg1
		dey
		lda	(syszp),y	; minute
		jsr	checkbcd
		bcs	jmperr1
		cmp	#$60
		bcs	illarg1
		dey
		lda	(syszp),y	; hour
		jsr	checkbcd
		bcs	jmperr1
		cmp	#$24
		bcs	illarg1
		dey
		lda	(syszp),y	; day
		beq	illarg1
		jsr	checkbcd
		bcs	jmperr1
		sta	syszp+2		; daymax depends on month and leap year
		dey
		lda	(syszp),y	; month
		beq	illarg1
		jsr	checkbcd
		bcs	jmperr1
		cmp	#$13
		bcs	illarg1
		jsr	bcdtohex
		sta	syszp+3		; remember month in hex for max of day
		dey
		lda	(syszp),y	; year
		jsr	checkbcd
		bcs	jmperr1
		sta	syszp+4
		dey
		lda	(syszp),y	; century
		jsr	checkbcd
		bcs	jmperr1
		sta	syszp+5
		dey
		lda	(syszp),y	; weekday
		cmp	#$08
		bcs	jmperr1
		;; check maximum of day
		lda	syszp+2		; day to A
		ldy	syszp+3		; month in hex to y
		cmp	daymonth,y	; is day >= days+1 of this month
		bcc	endcheckdate	; if no, write date
		cpy	#2		; is february ?
		bne	illarg1		; if no, leap year is irrelevant
		cmp	#$30		; is day >= 30
		bcs	illarg1		; if yes, leap year is irrelevant
		;; month==2, date==29, so check for leap year
		lda	syszp+4		; is year equal 0 ?
		bne	year4leap_	; if not, leap year equiv to year%4==0
		lda	syszp+5		; century to A
		jsr	bcdtohex
		and	#$03		; is century%4 equal 0 ?
		beq	endcheckdate	; if yes, it's a leap year
illarg1:	lda	#lerr_illarg
jmperr1:	jmp	lkf_catcherr
year4leap_:	jsr	bcdtohex
		and	#$03		; is year%4 equal 0 ?
		bne	illarg1		; if no, it's not a leap year
endcheckdate:	;; copy argument to date
		sei
		ldy	#end_of_date-date-1
	-	lda	(syszp),y
		sta	date,y
		dey
		bpl	-
		jsr	write_time
		ldx	lk_ipid
		lda	lk_tstatus,x
		and	#~(tstatus_szu)
		sta	lk_tstatus,x
		cli
		clc
		rts


	;; rtc api: rtc_raw_date
	;; write date and time to CIA1
	;; < X/Y address of storage filled with date
	;; no error checking is done
	;; if it is not sure, that the syntax is correct use rtc_date_write

rtc_raw_write:
		php
		sei
		stx	syszp
		sty	syszp+1
		ldy	#end_of_date-date-1
	-	lda	(syszp),y
		sta	date,y
		dey
		bpl	-
		jsr	write_time
		plp
		rts


;;; main -------------------------------------------------------------------

main:
		ldx	#$ff
		ldy	#$ff
		jsr	lkf_sleep
		nop
		jmp	main


end_of_permanent_code:	
;;; initialisation data ----------------------------------------------------

		.byte $0c
		.word +

howto_txt:	.text "usage: cia1rtc",$0a,0

	+

;;; initialisation ---------------------------------------------------------

hiaddr_modstr:	bit	module_struct
		
initialize:
		;; parse commandline
		ldx	userzp
		cpx	#1
		beq	normal_mode
		
HowTo:		ldx	#stdout
		bit	howto_txt
		jsr	lkf_strout
		lda	#1
		rts
		
normal_mode:
		;; free memory used for commandline arguments
		ldx	userzp+1
		jsr	lkf_free
		nop
		lda	#0
		jsr	lkf_set_zpsize
		nop

		;; install alarm handler to update date
		ldx	#<alert_handler
		ldy	alert_handler-1		; #>alert_handler
		jsr	lkf_hook_alert
		nop
	
		;; enable cia alarm interrupt
		lda	#$84
		sta	CIA1_ICR

		;; register module
		ldx	#<module_struct
		ldy	hiaddr_modstr+2		; #>module_struct 
		jsr	lkf_add_module
		nop
	
		;; can't call lkf_fix_module, 
		;; as this would unlock the alarm handler
		;; must stay a process, so just wait
		jmp	main
				
end_of_code:
