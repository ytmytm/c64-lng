		;; For emacs: -*- MODE: asm; tab-width: 4; -*-
		
		;; main initialization

#include <config.h>
		
#include MACHINE_H		
#include <system.h>
#include <ksym.h>

;; bootstrap_system:	
	
start:
		sei						; disable interrupts
		cld						; clear decimal flag
		ldx  #255
		txs						; init stack pointer

#ifdef HAVE_SCPU
#include <scpu.h>
		sta  SCPU_MIRROR_SCR1	; SCPU should update $0400-$07ff
#endif
		SPEED_MAX		; switch to fast mode

		;; include machine specific reset code

#		include MACHINE(reset.s)

		;; erase zeropage and stack (not really needed)
		ldx  #2
		lda  #0
	-	sta  0,x
		inx
		bne  -
	-	sta  $100,x
		inx
		bne  -
		
		;; set pointer to new interrupt routine
		ldx  #<lkf_irq_handler
		ldy  #>lkf_irq_handler
		stx  $fffe
		sty  $ffff
		ldx  #<lkf_nmi_handler
		ldy  #>lkf_nmi_handler
		stx  $fffa
		sty  $fffb
		ldx  #<lkf_panic		; reset_handler ???
		ldy  #>lkf_panic		; never called, because ROM will be there
		stx  $fffc
		sty  $fffd

		;; first init process table
		lda  #0
		ldx  #$20				; max number of tasks (32)
	-	sta  lk_tstatus,x
		sta  lk_tnextt,x
		sta  lk_tslice,x
		sta  lk_ttsp,x
		dex
		bpl  -

		;; 2nd init system data
		lda  #$ff				; "system is idle" and there is no task
		sta  lk_ipid			; to switch to
		sta  lk_sleepipid		; no one to wakeup (no task is sleeping)
		lda  #1
		sta  lk_timer			; switch to next task on next IRQ
		lda  #0
		sta  lk_tsp				; (just empty)
		sta  lk_systic			; reset system's jiffy-counter
		sta  lk_systic+1
		sta  lk_systic+2
		sta  lk_sleepcnt
		sta  lk_sleepcnt+1		; wait a long time before alling _wakeup
	    lda  #0
		sta  lk_locktsw			; taskswitching is enabled (default)
		lda  #0
		sta  lk_semmap
		sta  lk_semmap+1
		sta  lk_semmap+2
		sta  lk_semmap+3
		sta  lk_semmap+4		; no ressources used
		sta  lk_taskcnt
		sta  lk_taskcnt+1		; no tasks yet
		sta  lk_nmidiscnt
		sta  lk_modroot
		sta  lk_modroot+1		; no modules available yet
		sta  lk_consmax			; no consoles available yet

		;; initialize internal memory
		ldx  #0
	-	lda  #0
		sta  lk_memnxt,x
		lda  #$ff
		sta  lk_memown,x
		inx
		bne  -
		
		ldx  #31
	-	lda  _initmemmap,x
		sta  lk_memmap,x
		dex
		bpl  -

		ldx  #31				; initialize SMB stuff
	-	lda  #$ff
		sta  lk_smbmap,x
		lda  #0
		sta  lk_smbpage,x
		dex
		bne  -
		
		;; clean up zeropage
		ldx  #$0f				; 16 bytes for each segment
		lda  #0
	-	sta  tmpzp,x
		sta  syszp,x
		sta  userzp,x
		dex
		bpl  -

		jsr  lkf_locktsw		; disable taskswitches with enabled IRQ

#		include MACHINE(irqinit.s)

		;; allocate (lock) kernel-memory
		jsr  lkf_locktsw		; raw_alloc does unlocktsw!
		lda  #$20				; begin of kernel ($2000 = 8192)
		sta  tmpzp+3
		lda  #>lkf_end_of_kernel
		sec
		sbc  #$20
		sta  tmpzp
		lda  #memown_sys
		sta  tmpzp+4
		jsr  lkf__raw_alloc		; allocate kernel code area
		jsr  lkf_locktsw		; raw_alloc does unlocktsw!
		lda  #$c0
		sta  tmpzp+3
		lda  #4
		sta  tmpzp
		jsr  lkf__raw_alloc		; allocate kernel data area
				
		cli						; taskswitching is still disabled (!)
		
#ifdef HAVE_REU
		;; check for REU

		#include <reu.h>

		;; non destructive test first
		ldx  #20
		lda  REU_status
		cmp  #$ff
		beq  no_reu
		ldy  REU_control
	-	cmp  REU_status
		bne  no_reu
		cpy  REU_control
		bne  no_reu
		dex
		bpl  -
		lda  #$ff		
		cmp  REU_BASE+$1f		; (is this save?)
		beq  more_reu

		;; too bad, can't print message, since console driver may rely on REU!
no_reu:
to_panic:
		#include MACHINE(reboot.s)

more_reu:
		;; read/write test
		ldx  #6
	-	cpx  #4
		beq  +
		lda  #$55
		sta  REU_BASE+2,x
		cmp  REU_BASE+2,x
		bne  no_reu
		lda  #$aa
		sta  REU_BASE+2,x
		cmp  REU_BASE+2,x
to_no_reu:
		bne  no_reu
	+	dex
		bpl   -
		;; final (functional test)
		ldx  #memown_sys
		ldy  #$80				; no I/O area
		jsr  lkf_spalloc
		bcs  to_panic
		stx  syszp+1
		ldy  #0
		sty  syszp
	-	tya
		sta  (syszp),y			; fill page with constants
		iny
		bne  -
		sty  REU_intbase
		stx  REU_intbase+1
		sty  REU_reubase
		lda  #$04
		sta  REU_reubase+1
		sty  REU_reubase+2
		sty  REU_translen
		lda  #1
		sta  REU_translen+1
		sty  REU_irqmask
		sty  REU_control
		lda  #REUcmd_int2reu|REUcmd_noff00|REUcmd_load|REUcmd_execute
		sta  REU_command		; copy internal page into REU
		lda  #REUcontr_fixreuadr
		sta  REU_control
		lda  #REUcmd_reu2int|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; fill internal page with 0
	-	lda  (syszp),y			; verify REU operation
		bne  to_no_reu
		iny
		bne  -
		jsr  lkf_pfree			; (free tmporary page)

		lda  lk_archtype
		ora  #larchf_reu		; set REU-flag in archtype
		sta  lk_archtype
#endif
		;; init console and print short welcome message
		jsr  console_init

		;; machine type
		jsr  print_machine_type
		
		;; calibrate delay loop
		jsr  calibrate_delay

		;; try to figure out, if we are accelerated by a SCPU
		lda  lkf_delay_calib_hi
		cmp  #3
		bcs  +
		lda  lk_archtype		; seem to have a SCPU running
		ora  #larchf_scpu
		sta  lk_archtype

	+	;; activate keyboard
		jsr  keyboard_init

		ldx  #0
	-	lda  welcome_txt,x
		beq  +
		jsr  lkf_printk
		inx
		bne  -
	+	
		;; spawn init task		
		lda  #0
		sta  userzp
		sta  userzp+1
		sta  userzp+2			; nothing at stdin/stdout/stderr
		lda  #0					; lowest possible priority (don't change!)
		ldx  #<lkf_init
		ldy  #>lkf_init
		jsr  add_task_simple	; add (first) task
		jsr  lkf_unlocktsw
		cli
	-	jmp  -					; fade away (should not be reached)
		
welcome_txt:
		.byte $0a
		.text "Welcome to LUnix next generation (LNG)",$0a
		.text "Version 0.16, Jan 27 2000",$0a,$0a
		.text "Compile time options:",$0a
#ifdef PETSCII
		.text "  - PETSCII character encoding",$0a
#endif
#ifdef VERBOSE_ERROR
		.text "  - verbose error messages",$0a
#endif
#ifdef PRINT_IECMSG
		.text "  - print CBM (channel 15) messages",$0a
#endif
#ifdef VDC_CONSOLE
  		.text "  - VDC console",$0a
#endif
#ifdef MULTIPLE_CONSOLES
		.text "  - multiple consoles",$0a
#endif
#ifdef HAVE_REU
		.text "  - support for REU",$0a
#endif
#ifdef HAVE_SCPU
		.text "  - SuperCPU compatibility",$0a
#endif
#ifdef ALWAYS_SZU
		.text "  - ignore SZU bit (always set)",$0a
#endif
#ifdef HAVE_256K
		.text "  - 256k RAM C128 compatibility",$0a
#endif
		.byte 0

txt_c64:
		.text "Commodore 64",0
txt_c128:
		.text "Commodore 128",0
txt_pal:
		.text " (PAL)",0
txt_ntsc:
		.text " (NTSC)",0
txt_50hz:
		.text " on 50Hz power",$0a,0
txt_60hz:
		.text " on 60Hz power",$0a,0

print_machine_type:
		lda  lk_archtype
		and  #larchf_type
		cmp  #larch_c64
		beq  +
		cmp  #larch_c128
		bne  ++
		ldy  #txt_c128-txt_c64
		.byte $2c
	+	ldy  #txt_c64-txt_c64
		jsr  mout
	+	lda  lk_archtype
		ldy  #txt_pal-txt_c64
		and  #larchf_pal
		bne  +
		ldy  #txt_ntsc-txt_c64
	+	jsr  mout
		lda  CIA1_CRA			; on c64 and c128
		ldy  #txt_50hz-txt_c64
		and  #%10000000
		bne  mout
		ldy  #txt_60hz-txt_c64
mout:	lda  txt_c64,y
		beq  +
		jsr  lkf_printk
		iny
		bne  mout
	+	rts
				
		;; initial memory map (every 1-bit is an available page)

#		include MACHINE(initmemmap.s)

add_task_simple:
		sei
		pha
		lda  userzp
		sta  syszp		
		lda  userzp+1
		sta  syszp+1
		lda  userzp+2
		sta  syszp+2
		lda  #0
		sta  syszp+5			; no commandline arguments
#ifndef ALWAYS_SZU
		tya
		pha
		ldy  lk_ipid
		bmi  +
		lda  #tstatus_szu
		ora  lk_tstatus,y
		sta  lk_tstatus,y
	+	cli
		pla
		tay
		pla
		jsr  lkf_addtask
		ldy  lk_ipid
		bmi  +
		sei
		lda  #$ff-tstatus_szu
		and  lk_tstatus,y
		sta  lk_tstatus,y
		cli
	+	rts

#else
		pla
		jmp  lkf_addtask
#endif

		;; include code that initialises
		;; the keyboard and console
		;; (this code should also set lk_consmax)

#ifdef VDC_CONSOLE
# include "vdc_console_init.s"
#else
# include MACHINE(console_init.s)
#endif
		
#include MACHINE(keyboard_init.s)