		;; load and start a new process

#include <config.h>
#include <system.h>
#include <kerrors.h>
#include <fs.h>

		.global forkto

_alloc1_error:
		pla
		pla
		pla
		jmp  _outofmem

_load_error:
		tay
		pla
		pla

_fopen_error:
		pla
		pla
		tya
		jmp  catcherr

		;; function: forkto
		;; < A/Y = address of struct
		;; <		.byte stdin_fd, stdout_fd, stderr_fd
		;; <     .asc  "<filename>\0"
		;; <		optional: .asc "<parameter>\0"
		;; <              ...
		;; <    .byte 0

		;; > c=1:  error (error number in A)
		;; > c=0:  X/Y = childs PID
		;; changes: syszp(0,1,2,3,4,5,6,7)
		;; calls: fopen,spalloc,mpalloc,fgetc,exe_test,pfree,addtask,reloc_and_exec

forkto:
		pha						; address of struct (lo)
		clc
		adc  #3
		tax
		tya
		pha						; address of struct (hi)
		bcc  +
		iny
	+	txa
		ldx  #fmode_ro
		jsr  fopen
		tay
		bcs  _fopen_error
#ifndef ALWAYS_SZU
		ldy  lk_ipid
		sei
		lda  lk_tstatus,y
		ora  #tstatus_szu
		sta  lk_tstatus,y
		cli
#endif
		txa
		pha						; fd
		sta  syszp+7
		ldx  lk_ipid
		ldy  #0
		jsr  spalloc
		bcs  _alloc1_error
		txa
		pha						; start address (hi)
		ldy  #0
		sty  syszp
		ldx  syszp+7			; fd

	-	jsr  fgetc				; (szu won't help, syszp gets lost during fgetc!)

		sei
		sta  syszp+2
		pla						; start address (hi)
		pha						; start address (hi)
		sta  syszp+1
		lda  #0
		sta  syszp
		bcs  _ioerr
		lda  syszp+2
		sta  (syszp),y
		cli
		iny
		bne  -
		beq  +

_ioerr:		lda  syszp+2			; error code
		cmp  #lerr_eof
		bne  _load_error
	+
#ifndef ALWAYS_SZU
		ldx  lk_ipid
		lda  lk_tstatus,x
		ora  #tstatus_szu
		sta  lk_tstatus,x
#endif
		cli

		sty  syszp+6
		tya
		beq  +

		lda  #0
	-	sta  (syszp),y			; zero rest of page
		iny
		bne  -

	+	jsr  exe_test			; check binary format
		bcc  _exe_error			; wrong format, then exit with error

		sta  syszp+2			; remember number of needed pages
		cmp  #2					; set carry if >1 page needed
		pla						; start address (hi)
		sta  syszp+1
		bcc  +					; skip reallocating

		;; reallocate memory (task needs more than just a single page)
		ldx  lk_ipid
		ldy  #$80
		lda  syszp+2			; no. of pages to allocate
		jsr  mpalloc
		bcs  _alloc2_error
		lda  syszp+1			; old adr-hi
		sta  syszp+3
		stx  syszp+1			; new adr-hi
		ldy  #0
		sty  syszp
		sty  syszp+2
	-	lda  (syszp+2),y
		sta  (syszp),y
		iny
		bne  -
		ldx  syszp+3
		jsr  pfree

	+	ldy  syszp+6
		bne  _loaded			; already loaded all ?

		;; load rest of tasks code

		ldy  syszp+6
		pla						; fd
		tax
		pha						; fd
		lda  syszp+1			; adr-hi
		pha
		clc
		adc  #1
		pha

	-	jsr  fgetc
		sei
		sta  syszp+2
		pla
		pha
		sta  syszp+1
		lda  #0
		sta  syszp
		bcs  _end2
		lda  syszp+2
		sta  (syszp),y
		cli
		iny
		bne  -
		pla
		adc  #1
		pha
		tay
		lda  lk_memown,y		; ??? not very secure !
		cmp  lk_ipid
		bne  _exe_error			; (segfault)
		ldy  #0
		beq  -

_exe_error:
		lda  #lerr_illcode
		jmp  _load_error		; (4x pla)

_ioerrend:		
		pla
		lda  syszp+2
		jmp  _load_error

_alloc2_error:
		ldx  syszp+1
		jsr  pfree
		jmp  _alloc1_error

_end2:
		cli
		lda  syszp+2			; error code from last fgetc
		cmp  #lerr_eof
		bne  _ioerrend
		pla
		pla
		sta  syszp+1			; start address (hi)

_loaded:
		pla						; fd
		tax
		lda  syszp+1			; start address (hi)
		pha						; remember base address
		jsr  fclose
#ifndef ALWAYS_SZU
		ldy  lk_ipid
		sei
		lda  lk_tstatus,y
		ora  #tstatus_szu
		sta  lk_tstatus,y
		cli
#endif
		pla						; start address (hi)
		sta  syszp+3			; exe_paramter is base-address (hi)
		sta  syszp+5
		pla						; address of struct (hi)
		sta  syszp+5
		pla						; address of struct (lo)
		sta  syszp+4
		ldy  #0
		lda  (syszp+4),y
		sta  syszp				; local stdin fd
		iny
		lda  (syszp+4),y
		sta  syszp+1			; local stdout fd
		iny
		lda  (syszp+4),y
		sta  syszp+2			; local stderr fd
		ldx  #<reloc_and_exec
		ldy  #>reloc_and_exec
		lda  #7
		jsr  addtask
		bcs  _outofmem+2
		;; X/Y=PID of child
#ifndef ALWAYS_SZU
		sty  syszp
		ldy  lk_ipid
		sei
		lda  lk_tstatus,y
		and  #$ff-tstatus_szu
		sta  lk_tstatus,y
		ldy  syszp
		cli
#endif
		rts

_outofmem:
		lda  #lerr_outofmem
		jmp  catcherr

		;; function: reloc_and_exec
		;; executed in new task's context
		;; after initializing the environment

		;; < Y=exe-parameter (base-address hi)
		;; calls: exe_reloc
		;; changes: syszp(0,1)

reloc_and_exec:
		sei
#ifndef ALWAYS_SZU
		ldx  lk_ipid
		lda  lk_tstatus,x
		ora  #tstatus_szu
		sta  lk_tstatus,x
#endif
		sty  syszp+1
		lda  #0
		sta  syszp

		;; hand over the covered portion of internal memory
	-	lda  lk_ipid
		sta  lk_memown,y
		lda  lk_memnxt,y
		tay
		bne  -		
		cli
		jsr  exe_reloc
		nop						; (suicide on error)
		tya
		pha
		txa
		pha
		php
		rti						; continue with new task
