
; .o65 loader for LUnix, based on original code by Andre Fachat
; Maciej Witkowiak <ytm@elysium.pl>
; 24,28,30.11.2001, 18.11.2002

; TODO
; - some things seem to be calculated twice
; - get address of '_main' (entry point) from exported variables (later or never)
;   (execute.s and addtask.s will need changes then too (addtask allows only for page-hi addr))
; - note that load_block == fread

#include <system.h>
#include <config.h>
#include <kerrors.h>
#include <zp.h>

#ifdef HAVE_O65

#define	A_ADR		$80
#define	A_HIGH		$40      ; or'd with the low byte
#define	A_LOW		$20

#define	A_MASK		$e0      ; reloc type mask
#define	A_FMASK		$0f      ; segment type mask

#define	SEG_UNDEF	0
#define	SEG_ABS		1
#define	SEG_TEXT	2
#define	SEG_DATA	3
#define	SEG_BSS		4
#define	SEG_ZERO	5

#define	FM_OBJ		%00010000
#define	FM_SIZE		%00100000
#define	FM_RELOC	%01000000
#define	FM_CPU		%10000000

#define O65_OPTION_OS	1

#define O65_OS_LUNIX	2

		.global o65_loader

err_memory:	lda #lerr_outofmem
		SKIP_WORD
err_hdr:	lda #lerr_illcode
		pha
		ldx #lsem_o65		; unlock semaphore
		jsr unlock
		jsr fclose
		pla
		sec
		rts

		;; function: o65_loader
		;; loads and relocates .o65 format file
		;; > X - fd
		;; < C=1 - errorcode in A
		;; < C=0 - OK
		;; < A/Y - execute address (0,firstpage)

o65_loader:
		sec
		ldx #lsem_o65		; raise semaphore for o65 relocation
		jsr lock
		;; get mode
		jsr fgetc
		bcs err_hdr
		sta amode
		jsr fgetc
		bcs err_hdr
		;; check mode
		and #%10110000		; not quite correct (cpu 65816 not allowed here)
		bne err_hdr
		lda amode
		and #%00000011
		sta amode		; store align mode

		;; load rest of header data
		ldy #0
	-	jsr fgetc
		bcs err_hdr
		sta o65_header, y
		iny
		cpy #18
		bne -

		;; load and ignore header options
	-	jsr fgetc
		bcs err_hdr
		beq _cont		; no more options
		tay
		dey			; number of bytes that follow+1
		cpy #3			; 3 byte long option - may be OS
		beq +

	-	jsr fgetc
		bcs err_hdr
		dey
		bne -
		beq --

	+	jsr fgetc
		dey
		cmp #O65_OPTION_OS
		bne -
		jsr fgetc
		dey
		cmp #O65_OS_LUNIX
		beq -			; ignore version byte
		jmp err_hdr		; not LUnix - illegal code

_cont:
		;; zero segment check - zbase, zlen are ignored, zerod is not set
		;; system.h header is used to reference zero page locations, so
		;; no relocation is needed

		stx p1			; save fd
		;; align header lengths (as in original loader)
		lda tlen
		ldy tlen+1
		jsr doalign		; align text segment start
		clc
		adc dlen
		pha
		tya
		adc dlen+1
		tay
		pla
		jsr doalign
		clc
		adc bsslen
		pha
		tya
		adc bsslen+1
		tay
		pla
		;; total length of needed space (with aligned lengths) is in A/Y
		;; mpalloc allocates full pages only, so...
		iny			; ignore lowbyte and ++highbyte
		tya			; number of needed pages
		ldx lk_ipid		; owner
		ldy #$80		; mode - no I/O
		jsr mpalloc		; pagewise allocation
		bcc +
		jmp err_memory		; not enough memory
	+	txa
		sta textm+1
		tay
		lda #0
		sta textm

		;; compute textd, datad, bssd, zerod
		sec
		sbc tbase
		sta textd
		tya
		sbc tbase+1
		sta textd+1

		lda tlen
		ldy tlen+1
		jsr doalign
		clc
		adc textm
		pha
		tya
		adc textm+1
		tay
		pla
		sta datam
		sty datam+1
		sec
		sbc dbase
		sta datad
		tya
		sbc dbase+1
		sta datad+1

		lda dlen
		ldy dlen+1
		jsr doalign
		clc
		adc datam
		pha
		tya
		adc datam+1
		tay
		pla

		sec
		sbc bssbase
		sta bssd
		tya
		sbc bssbase+1
		sta bssd+1

		;; if error happens past this point - free allocated memory
		;; ok, memory is owned, now load text and data segments into memory
		ldx p1			; restore fd
		lda textm
		ldy textm+1
		sta p1
		sty p1+1
		lda tlen
		ldy tlen+1
		sta p2
		sty p2+1
		jsr load_block
		bcc +
		jmp err_filedata

	+	lda datam
		ldy datam+1
		sta p1
		sty p1+1
		lda dlen
		ldy dlen+1
		sta p2
		sty p2+1
		jsr load_block
		bcs err_filedata

		;; check for undefined variables, if there are any - exit with error
		jsr fgetc
		bcs err_file
		cmp #1			;lowbyte =1, hibyte =0
		bne err_references
		jsr fgetc
		bcs err_file
		bne err_file		;>1 undefined references!
		;; check if undefined variable is=="LUNIXKERNEL"

		ldy #0
	-	jsr fgetc
		bcs err_file
		beq +
		cmp lunix_kernel, y
		bne err_references
		iny
		bne -
	+	cmp lunix_kernel, y
		bne err_references

		stx p3			;save fd

		;; file pointer is at the start of text segment relocation table - relocate
		lda textm
		sec
		sbc #1
		sta p1
		lda textm+1
		sbc #0
		sta p1+1
		jsr o65_relocate	; relocate text segment

		ldx p3			; get fd
		lda datam
		ldy datam+1
		sec
		sbc #1
		sta p1
		tya
		sbc #0
		sta p1+1
		jsr o65_relocate	; relocate data segment

		;; ignore exported labels OR get main from there (otherwise start of text is main)

		;; close the file
		ldx p3
		jsr fclose
		;; ready to fork, A/Y is the execute address
		ldx #lsem_o65		; unlock semaphore
		jsr unlock
		lda textm
		ldy textm+1
		clc
		rts

err_references:	;; too many undefined references
		lda #lerr_illcode
		SKIP_WORD
err_file:	;; file is corrupt, free memory, close file
		lda #lerr_ioerror
		pha
		jsr fclose
		ldx textm+1
		jsr pfree
		pla
		SKIP_WORD
err_filedata:	ldx #lsem_o65		; unlock semaphore
		jsr unlock
		lda #lerr_ioerror
		sec
		rts

load_block:	;; load #p2 bytes into (p1) with fd==X
		lda p2
		ora p2+1
		beq +++
	-	jsr fgetc
		bcs err_file
		ldy #0
		sta (p1),y
		inc p1
		bne +
		inc p1+1
	+	lda p2
		bne +
		dec p2+1
	+	dec p2
		lda p2
		ora p2+1
		bne -
	+	clc
		rts

o65_relocate:	;; file pointer is at start of relocation table
		;; p1 holds start_of_segment-1, p2 is used, p3 is fd
		ldx p3			; fd
		jsr fgetc
		bcs err_file
		cmp #0
		bne +
		jmp o65_reloc_end
	+	cmp #255
		bne +
		lda #254
		clc
		adc p1
		sta p1
		bcc o65_relocate
		inc p1+1
		jmp o65_relocate
	+	clc
		adc p1
		sta p1
		bcc +
		inc p1+1		; (p1) is the relocation address

	+	ldx p3			; fd
		jsr fgetc
		bcs err_file
		tay
		and #A_MASK
		sta amode
		tya
		and #A_FMASK
		cmp #SEG_UNDEF
		bne +
		jsr o65_handle_undefined
		jmp o65_relocate

	+	jsr o65_reldiff
		ldy amode
		cpy #A_ADR
		bne +

		ldy #0
		clc
		adc (p1),y
		sta (p1),y
		iny
		txa
		adc (p1),y
		sta (p1),y
		jmp o65_relocate

	+	cpy #A_LOW
		bne +
		ldy #0
		clc
		adc (p1),y
		sta (p1),y
		jmp o65_relocate

	+	cpy #A_HIGH
		bne o65_relocate
		sta p2
		stx p2+1
		ldx p3			; fd
		jsr fgetc
		bcc +
		jmp err_file
	+	clc
		adc p2
		ldy #0
		lda p2+1
		adc (p1),y
		sta (p1),y
		jmp o65_relocate

o65_reloc_end:	clc
		rts

o65_reldiff:	; get difference to segment
		cmp #SEG_TEXT
		bne +
		lda textd
		ldx textd+1
		rts
	+	cmp #SEG_DATA
		bne +
		lda datad
		ldx datad+1
		rts
	+	cmp #SEG_BSS
		bne +
		lda bssd
		ldx bssd+1
		rts
	+	cmp #SEG_ZERO
		bne o65_reldiff_err
		lda #0			; don't relocate zero page - return $0000 as base
		tax
		rts
o65_reldiff_err:			; unknown segment type
		rts

o65_handle_undefined:
		;; handle undefined labels, now only LUNIXKERNEL (as base of virtual jumptable)
		;; in the future maybe LIB6502 for shared functions
		lda amode
		cmp #A_ADR		; only 16-bit relocation allowed here
		bne o65_reldiff_err
		jsr fgetc
		sta p2
		jsr fgetc
		ora p2
		bne o65_reldiff_err	; only relocation of label 0 allowed

		ldy #0
		lda (p1), y		; low byte in offset in virtual kernel jumptable
		tax			; warning! only 128 kernel calls!!!
		lda kfunc_tab, x
		sta (p1), y
		iny
		lda kfunc_tab+1, x
		sta (p1), y
		rts

doalign:	ldx amode		; increase given value to align it
		clc
		adc aadd, x
		and aand, x
		pha
		tya
		adc aadd+1, x
		and aand+1, x
		tay
		pla
		rts

; aligning tables
aadd:		.word 0,     1,     3,     255
aand:		.word $ffff, $fffe, $fffc, $ff00

; the only undefined reference is to base of virtual kernel jump table
lunix_kernel:	.text "LUNIXKERNEL",0

;;; ZEROpage: p1 2
; these don't really need to be on zerpage, but it is handy
;;; ZEROpage: p2 2
;;; ZEROpage: p3 1
;;; ZEROpage: amode 1
;;; ZEROpage: textm 2
;;; ZEROpage: datam 2
;p2:		.word 0
;p3:		.byte 0
;amode:		.byte 0
;textm:		.word 0			; aligned base address of everything
;datam:		.word 0

; o65_header (26 bytes)
o65_header:
tbase:		.word 0			; tbase
tlen:		.word 0			; tlen
dbase:		.word 0			; dbase
dlen:		.word 0			; dlen
bssbase:	.word 0			; bssbase
bsslen:		.word 0			; bsslen
textd:		;.word 0
zbase:		.word 0			; zbase (once)
datad:		;.word 0
zlen:		.word 0			; zlen  (once or never)
;zerod:		;.word 0
bssd:		;.word 0
stack:		.word 0			; stack (never)


#else
o65_loader:	rts			; need to put something...
#endif
