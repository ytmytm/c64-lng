; For emacs: -*- MODE: asm; tab-width: 4; -*-

		;; semaphore locking

#include <system.h>
#include <kerrors.h>
#include <config.h>
#include MACHINE_H

.global lock
.global unlock
.global bmap

		;; function: lock
		;; lock system semaphore
		;; < X=No. of semaphore
		;; <  c=0 - non blocking

		;; changes: tmpzp(5)

lock:		txa
		and  #$c0				; sem.num>40 ? then software-failure
		bne  _not_available
		php
		sei

		;; check, if the current task has already locked this semaphore
		txa
		and  #7
		tay
		lda  bmap,y				; 1<<y
		sta  tmpzp+5			; bit pattern
		txa
		lsr  a
		lsr  a
		lsr  a
		clc
		adc  #tsp_semmap
		tay
		lda  (lk_tsp),y
		and  tmpzp+5
		bne  _already_locked

		;; check, if the global semaphore is available
		lda  lk_semmap-tsp_semmap,y
		and  tmpzp+5
		bne  _block

		;; lock it
		lda  lk_semmap-tsp_semmap,y
		ora  tmpzp+5
		sta  lk_semmap-tsp_semmap,y
		lda  (lk_tsp),y
		ora  tmpzp+5
		sta  (lk_tsp),y

_already_locked:
		plp
		rts

_block:		plp
		bcc  _not_available
		txa
		pha						; remember number of semaphore
		lda  #waitc_semaphore
		jsr  block				; block with sem/sem-no
		pla
		tax
		sec
		jmp  lock				; try it again

_not_available:
		lda  #lerr_nosem
		jmp  catcherr

		;; function: unlock
		;; unlock locked system semaphore
		;; < X=No. of semaphore
		;; calls: mun_block

unlock:		clc
		php
		sei
		cpx  #40
		bcs  _already_locked	; return without error

		;; check, if the current task has already unlocked this semaphore
		txa
		and  #7
		tay
		lda  bmap,y				; 1<<y
		sta  tmpzp+5			; bit pattern
		txa
		lsr  a
		lsr  a
		lsr  a
		sta  tmpzp+4			; byte number
		clc
		adc  #tsp_semmap
		tay
		lda  (lk_tsp),y
		and  tmpzp+5
		beq  _already_locked	; return without error

		;; unlock

		eor  (lk_tsp),y
		sta  (lk_tsp),y
		ldy  tmpzp+4
		lda  tmpzp+5
		eor  #$ff				; be sure the bit is cleard and not set
		and  lk_semmap,y
		sta  lk_semmap,y
		txa
		pha						; remember number of semaphore

		jsr  _sem_cleanup		; call cleanup-routine

		pla
		tax
		lda  #waitc_semaphore
		jsr  mun_block			; unblock all waiting tasks

		plp
		rts

_sem_cleanup:
		tya
		bne  +					; undefined semaphores

		;; defined semaphores
		lda  #$2c				; (op-code of BIT $xxxx instruction)
		cpx  #lsem_irq1
		beq  _irq1off
		cpx  #lsem_irq2
		beq  _irq2off
		cpx  #lsem_irq3
		beq  _irq3off
		cpx  #lsem_alert
		beq  _alertoff
		cpx  #lsem_nmi
		beq  _nmioff

	+	rts


_alertoff:						; (alert off)
		sta  _irq_alertptr
#ifdef HAVE_CIA
		lda  #4
		sta  CIA1_ICR
#endif
		rts

_irq1off:						; (remove IRQ-job 1)
		sta  _irq_jobptr
		rts

_irq2off:						; (remove IRQ-job 2)
		sta  _irq_jobptr+3
		rts

_irq3off:						; (remove IRQ-job 3)
		sta  _irq_jobptr+6
		rts

_nmioff:						; (remove NMI-job)
		lda  lk_nmidiscnt		; NMI already disabled ?
		bne  +
		jsr  __nmi_dis			; if not, then disable now		
	+	php
		sei
		lda  $2c				; remove NMI-Job
		sta  _nmi_jobptr
		lda  #<_nmi_donothing	; reset enable and disable call
		sta  _nmi_dis+1
		sta  _nmi_ena+1
		lda  #>_nmi_donothing
		sta  _nmi_dis+2
		sta  _nmi_ena+2
_nmi_donothing:
		plp
		rts

__nmi_dis:
		php
		sei
		jmp  _nmi_dis

bmap:	.byte 1,2,4,8,16,32,64,128
