		;; For emacs: -*- MODE: asm; tab-width: 4; -*-

		;; taskswitcher

		;; timer 1 of CIA $cc00 generates IRQs every 1/64 second
		;; timer 2 of CIA $cc00 measures the exact time spend in the task
		;;                      since the last IRQ
		
		;; every process can force a taskswitch, if there is nothing
		;; more to do. (the unused CPU time can't be collected for later
		;; use!)

		;; C128 code by Maciej 'YTM/Alliance' Witkowiak <ytm@friko.onet.pl>
		;; 10,11,12.01.2000 - required changes, still doesn't work
		;; 18.01 - finally works - swapper_idle was overwritting last stack, now it
		;;	   has own one at $00100 (remember to always set MMU_P1H!)
		;; 19.01 - expanded C128 have problems with that $00100, changed it
		;;	   to $1d000

#include <config.h>
		
#include MACHINE_H				
#include <system.h>
#include <kerrors.h>

.global force_taskswitch
.global irq_handler
.global _irq_jobptr
.global _irq_alertptr
.global idle_task
.global locktsw
.global unlocktsw

;;; externals:	 _wakeup suicerrout brk_handler

		;; function: force_taskswitch
		;; force a task (context) switch
		;; changes: tmpzp(0,1,2,3,4,5,6,7)
		
force_taskswitch:
		;; emulate IRQ
		php						; push status
		sei						; no IRQ here please
		pha						; push akku
		txa
		pha						; push X
		tya
		pha						; push Y
		;; adapt return address
		cld						; must do this, to make adc work properly
		clc
		tsx
		txa
		adc  #5
		tax
		inc  $100,x				; correct return address
		bne  +					; because rti will be used instead of rts !
		inx
		inc  $100,x
		;; jump to end of time slice
	+	lda  #1
		sta  lk_timer
		jmp  irq_handler_2

to_brk:	jmp  brk_handler

irq_handler:
		pha
		txa
		pha
		tya
		pha
		tsx
		lda  $104,x
		and  #$10
		bne  to_brk
 
irq_handler_2:
		;; push memory configuration
		GETMEMCONF				; get current memory configuration
		pha						; (remember)
		lda  #MEMCONF_SYS		; change value for IRQ/NMI memory conf.
		SETMEMCONF				; -> C64-KERNAL-ROM + I/O
		cld						; (might need arithmetic)
		lda  lk_ipid
		bmi  _idle				; skip next, if we're idle

		;; system dependend taskswitching core
		;;  includes:	 _checktimer
		;;               _irq_jobptr
		;;               _irq_alertptr
		
#		include MACHINE(tasksw.s)
				
		;; taskswitching...
_idle:
		ldy  lk_locktsw			; don't to anything, 
		bne  do_taskswitch		; if taskswitching is locked
								; if CPU has been idle...
		and  #$7f				; is there a task to switch to from idle state
		cmp  #$20
		tay
		bcc  _activate_this		; yes, then go ahead
		
	-	lda  #1					; no, then wait 1/64s and look again
		sta  lk_timer
		jmp  _checktimer

		;; a stack overflow is a serious thing (and hard to track)
_stackoverflow:	
		ldx  #255
		txs						; be sure there now is enough stack available
		lda  #lerr_stackoverflow
		jmp  suicerrout			; this is a dirty hack and might cause
		                        ; problems, because interrupts may get lost!
		                        ; but its a rare situation and i want to save
		                        ; memory
		
	-	ora  #$80				; set flag
		sta  lk_locktsw
		bne  --					; (always jump)
		
do_taskswitch:
		lda  lk_locktsw			; a way to disable taskswitches without sei/cli
		bne  -

		;; save environment of current task (zeropage and stack)

		;; task superpage:
		;;  offset				contents
		;;  -----------------------------------------
		;;  tsp_swap,...		copy of used zeropage
		;;  ...,$ff				copy of used stack
	
#ifndef HAVE_REU
		;; taskswitching without REU

		
		lda  lk_tsp+1
# ifndef C128
		sta  _stsl+2			; self modifying code for extra performance
# endif
		sta  _zpsl+2
		
		;; swap out stack
		
		tsx						; remember stackpointer
		txa
		eor  #$ff
		ldy #tsp_stsize
		sta  (lk_tsp),y
		clc						; exact check for stackoverflow
		adc  #tsp_swap
		bcs  _stackoverflow
		ldy  #tsp_zpsize
		adc  (lk_tsp),y
		bcs  _stackoverflow
# ifndef C128
		inx
		
	-	pla						; stackpointer must be initialized with 0 (!)
_stsl:	sta  .0,x
		inx
		bne  -
# endif

		
		;; swap out zeropage
		
# ifndef ALWAYS_SZU
		ldy  #tsp_zpsize
		lda  (lk_tsp),y			; size of used zeropage
		beq  +
		tax
		dex

	-	lda  userzp,x			; if zpsize is zero 1 byte will be copied
_zpsl:	sta  .tsp_swap,x		; (doesn't matter, i think)
		dex
		bpl  -

	+	ldy  lk_ipid
		lda  lk_tstatus,y		; task status
		and  #tstatus_szu		; check if system zeropage is used
		beq  +					; not used, then skip

		lda  lk_tsp+1			; extra 8 zeropage bytes for
		sta  _szsl+2			; kernel or (shared-) library routines
		ldx  #7
	-	lda  syszp,x
_szsl:	sta  .tsp_syszp,x
		dex
		bpl  -
	+
# else
		;; always add 8 bytes szu to zeropage (syszp = userzp-8)
		ldy  #tsp_zpsize
		lda  (lk_tsp),y			; size of used zeropage
		clc
		adc  #7
		tax
	-	lda  userzp-8,x			; if zpsize is zero 1 byte will be copied
_zpsl:	sta  .tsp_swap-8,x		; (doesn't matter, i think)
		dex
		bpl  -
		ldy  lk_ipid
# endif
		
#else
		;; taskswitching with REU
# include <reu.h>
		
# ifndef ALWAYS_SZU
#  msg REU based taskswitcher assumes ALWAYS_SZU set
# endif

		tsx						; remember stackpointer
		txa
		eor  #$ff
		sta  REU_translen
		ldy	 #tsp_stsize
		sta  (lk_tsp),y
		clc						; exact check for stackoverflow
		adc  #tsp_swap
		bcs  _stackoverflow
		ldy  #tsp_zpsize
		adc  (lk_tsp),y
		bcs  _stackoverflow
		
		inx
		stx  REU_intbase
		lda  #1
		sta  REU_intbase+1
		lda  #0
		sta  REU_translen+1
		sta  REU_control
		sta  REU_reubase
		sta  REU_reubase+1
		sta  REU_reubase+2
		lda  #REUcmd_int2reu|REUcmd_load|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy stack to REU

		lda  lk_tsp+1
		sta  REU_intbase+1
		lda  #REUcmd_reu2int|REUcmd_load|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy stack from REU into tsp

		ldy  #tsp_zpsize
		lda  (lk_tsp),y			; size of used zeropage
		clc
		adc  #8
		sta  REU_translen		; (translen+1 is still 0)
		lda  #userzp-8			; (equal to #syszp)
		sta  REU_intbase
		lda  #0
		sta  REU_intbase+1
		lda  #REUcmd_int2reu|REUcmd_load|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy zeropage to REU

		lda  #tsp_swap-8
		sta  REU_intbase
		lda  lk_tsp+1
		sta  REU_intbase+1
		lda  #REUcmd_reu2int|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy zeropage from REU into tsp
				
		ldy  lk_ipid
#endif
		
		; done, y holds IPID of current task
		
		;; switch to the next task

		ldx  lk_tnextt,y		; IPID of next task
		lda  lk_tstatus,y
		and  #tstatus_susp		; switchted away from a suspended
		beq  +					; task ?
		lda  #$ff				; yes, then destroy old next-pointer
		sta  lk_tnextt,y
	+	txa

_activate_this:
		sta  lk_ipid
		bmi  _swapperidle		; no task to switch to, then we're idle
		tay
		lda  lk_tslice,y		; time for the next task
		sta  lk_timer
		lda  lk_ttsp,y			; superpage of the next task
		sta  lk_tsp+1

		;; reload environment of the task (zeropage and stack)
		
#ifndef HAVE_REU
		;; reload without REU
		
		sta  _zpll+2
# ifndef C128
		sta  _stll+2			; not needed for C128 swap-in
# endif

		;; swap in zeropage
		
# ifndef ALWAYS_SZU
		lda  lk_tstatus,y		; task status
		and  #tstatus_szu		; check if system zeropage is used
		beq  +					; not used, then skip

		lda  lk_tsp+1			; extra 8 zeropage bytes for
		sta  _szll+2			; kernel or (shared-) library routines
		ldx  #7
_szll:	lda  .tsp_syszp,x
		sta  syszp,x
		dex
		bpl  _szll
		
	+	ldy  #tsp_zpsize		; size of zeropage
		lda  (lk_tsp),y
		beq  +
		tax
		dex
		
_zpll:  lda  .tsp_swap,x
		sta  userzp,x
		dex
		bpl  _zpll
	+
# else
		ldy  #tsp_zpsize		; size of zeropage
		lda  (lk_tsp),y
		clc
		adc  #7
		tax
_zpll:  lda  .tsp_swap-8,x		; (alwasy_szu makes this loop 96us longer)
		sta  userzp-8,x
		dex
		bpl  _zpll		
# endif

		;; swap in stack
		
# ifdef C128
		ldy  #tsp_stsize
		lda  (lk_tsp),y
		eor #$ff
		tax
		txs
						;; THIS is real stack-swapping (always 7 cycles)
		lda lk_ipid			;; IPID=(0..31), stacks are in $00-$1f, effective
		sta MMU_P1L			;; address $10000-$11f00

#  ifndef HAVE_256K
		;; in 256k C128 all stacks are in the same bank (idle one is at $1d000)
		lda #1				;; currently this is required, as idle_task
		sta MMU_P1H			;; have stack in $00100 and I don't want to waste
						;; 8k block of shadowed memory starting at $12000
#  endif

# else
		;; not C128
		ldx  #$ff
		txs
		ldy  #tsp_stsize
		lda  (lk_tsp),y
		tax
		eor  #$ff
		sta  _stll+1
		
_stll:	lda  .0,x
		pha
		dex
		bne  _stll
# endif

#else
		;; reload environment using REU

		sta  REU_intbase+1		; (A is [lk_tsp+1])
		lda  #tsp_swap-8
		sta  REU_intbase
		ldy  #tsp_zpsize		; size of zeropage
		lda  (lk_tsp),y
		clc
		adc  #8
		sta  REU_translen
		ldx  #0
		stx  REU_translen+1
		stx  REU_reubase
		stx  REU_reubase+1
		stx  REU_reubase+2
		stx  REU_control
		lda  #REUcmd_int2reu|REUcmd_load|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy TSP-zeropage into REU
		
		lda  #userzp-8			; (equal to #syszp)
		sta  REU_intbase
		stx  REU_intbase+1
		lda  #REUcmd_reu2int|REUcmd_load|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy TSP-zp (from REU) into real zeropage

		ldy  #tsp_stsize
		lda  (lk_tsp),y
		sta  REU_translen
		eor  #$ff
		tax
		txs
		inx
		stx  REU_intbase
		lda  lk_tsp+1
		sta  REU_intbase+1
		lda  #REUcmd_int2reu|REUcmd_load|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy TSP-stack into REU

		lda  #1
		sta  REU_intbase+1
		lda  #REUcmd_reu2int|REUcmd_load|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy TSP-stack (from REU) into real stack
#endif
 		jmp  _checktimer		; look for timer interrupts
		
_swapperidle:
		;; if there is no other task to switch to
		;; we have the problem, that we can't return by rti, because there
		;; is nothing to return to.

#ifdef C128
		;; we're using end of stack, so we must provide a stack

# ifdef HAVE_256K
		;; my expanded C128 have problems with switching stack bank
		;; so here I use address $1d000 (under I/O), but it can be 
		;; anywhere in bank 1 (or rather: current bank)
		ldx #$d0
		stx MMU_P1L
		ldx #255
# else
		;; this works in VICE X128, so it should work in a stock C128
		;; here I use address $00100 (default), but it can be any page,
		;; where last 10 (at least) bytes are unused
		ldx #1
		stx MMU_P1L
		dex						;X=0
		stx MMU_P1H
		dex						;X=255
# endif
#else
		;; not C128
		ldx  #255
#endif
		txs
		lda  #>idle_task
		pha						; pc lo
		lda  #<idle_task
		pha						; pc hi
		lda  #0
		pha						; sr
		pha						; a
		pha						; x
		pha						; y
		GETMEMCONF				; get current memory configuration
		pha						; (1)
		jmp  _checktimer
		
idle_task:
		;; this is, what the system does, when there is nothing to do
		;; (do what you want here)
		jmp  idle_task

		;; function: locktsw
		;; lock taskswitching without (!) disabling IRQ
		;;  used by:	mpalloc spalloc pfree
locktsw:   
		inc  lk_locktsw
		rts

		;; function: unlocktsw
		;; problem=
		;; task can not be killed while it has disabled taskswitches,
		;; IRQ or NMI handler may not call functions, that disable
		;; taskswitches this way. (may lead to data inconsistency)
		;; (a NMI handler must not call any kernel routine for that reason !)
		;; another problem is killing/sending signals to a suspended task !

		;; might call force_taskswitch
		;; changes: context
		
unlocktsw:
		php
		sei
		dec  lk_locktsw
		lda  lk_locktsw
		asl  a					; check bit 7 and bits 0-6
		bne  +					; (if there are nested "locktsw"s)
		;; taskswitching is enabled again, check if there is a pending
		;; taskswitch
		bcc  +
		sta  lk_locktsw			; clear bit 7
		pla
		and  #$04				; check I-flag
		bne  ++					; I-flag set, so don't do a taskswitch
		cli
		jmp  force_taskswitch

	+	plp
	+	rts

