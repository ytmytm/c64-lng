		;; switch to LUnix' memory configuration

		lda #%00111110			; only RAM+I/O, bank 0
		sta MMU_CR
		sta MMU_IOCR
		sta MMU_PCRA				; also as preconfig A (kernel default)
		sta MMU_PCRB				; also as preconfig B (user default)
		lda #%00000000			; noshare, VIC in bank 0
		sta MMU_RCR
		ldx #0
		stx MMU_P0H
		stx MMU_P0L				; page 0 at $00000
		inx
		stx MMU_P1H
		stx MMU_P1L				; page 1 at $10100

#ifdef VDC_CONSOLE
		lda  VIC_YSCL			; switch off VIC screen
		and  #%11101111			; (makes compuer run slightly faster)
		sta  VIC_YSCL
#endif

		;; stop all timer, and disable all (known) interrupts
		lda  #%00000000
		sta  CIA1_CRA			; stop timer 1 of CIA1
		sta  CIA1_CRB			; stop timer 2 of CIA1
		sta  CIA2_CRA			; stop timer 1 of CIA2
		sta  CIA2_CRB			; stop timer 2 of CIA2
		lda  #%01111111
		sta  CIA1_ICR
		sta  CIA2_ICR
		lda  CIA1_ICR
		lda  CIA1_ICR
		lda  CIA2_ICR
		lda  CIA2_ICR
		lda  #0
		sta  VIC_IRM
		lda  VIC_IRQ
		sta  VIC_IRQ

		;; CIA initialization
		lda  #%11111111
		sta  CIA1_DDRA
		lda  #%00111111
		sta  CIA2_DDRA
		lda  #%00000000
		sta  CIA1_DDRB
		sta  CIA2_DDRB

		;; set type of architecture (first shot)
		;; ---------------------------------------------------------------
		
		;; (Read $0a03 - $ff=PAL, $00=NTSC)
		;lda  #larch_c128
		;ldx  $0a03
		;beq  +					; (ntsc)
		;ora  #larchf_pal		; (pal)
	;+	sta  lk_archtype


		;; alternate (better) solution from comp.sys.cbm
		;; ---------------------------------------------------------------

		ldx  #larch_c128
	-	bit  VIC_RC
		bpl  -					; wait for rasterline  127<x<256
		lda  #24				; (rasterline now >=256!)
	-	cmp  VIC_RC				; wait for rasterline = 24 (or 280 on PAL)
		bne  -
		lda  VIC_YSCL			; 24 or 280 ?
		bpl  +
		ldx  #larch_c128|larchf_pal|larchf_8500
	+	stx  lk_archtype

