;; for emacs: -*- MODE: asm; tab-width: 4; -*-

		;; filesystem interface

#include <config.h>
#include <system.h>
#include <fs.h>
#include <kerrors.h>

		;; use one SMB for each opened file (lock into fs.h for details)
		;;  byte 0 - major
		;;  byte 1 - minor
		;;  byte 2 - reference counter (read)
		;;  byte 3 - reference counter (write)
		;;  byte 4 - flags
		;;  5..31  - undefined, device specific
		
		.global ref_increment
		.global io_return_error
		.global io_return
		.global alloc_pfd
		.global fdup
		
		.global fopen
		.global fputc
		.global fgetc
		.global fclose
		.global fcmd
		.global fopendir
		.global freaddir
		.global fgetdevice

		;; function: resolve_dev
		;; resolve device from path prefix
		;; changes: syszp(0,1,2)

		;; < A/Y=filename (including path) X->syszp+2
		;; > X/Y=pdminor/pdmajor
resolve_dev:
#ifndef ALWAYS_SZU
		sei
		sta  syszp
		sty  syszp+1
		stx  syszp+2
		ldx  lk_ipid
		lda  #tstatus_szu
		ora  lk_tstatus,x
		sta  lk_tstatus,x
		cli
#else
		sta  syszp
		sty  syszp+1
		stx  syszp+2		
#endif
		ldy  #0
		lda  (syszp),y
		cmp  #"/"
		beq  alter_dev
		ldy  #tsp_pdmajor
		lda  (lk_tsp),y
		beq  alter_dev+2
		pha
		iny
		lda  (lk_tsp),y			; load minor
		tax						; x=tsp_pdminor
		pla
		tay						; y=tsp_pdmajor
		clc
		rts

alter_dev:
		ldx  #0
		iny						; Y=1

	-	lda  pprefix,x
		beq  +
		cmp  (syszp),y
		bne  ++
		iny
		inx
		bne  -		

	+	lda  (syszp),y			; prefix only or terminated with
		beq  found+1			; "/" or ":"
		cmp  #"/"
		beq  found
		cmp  #":"
		beq  found

	-	lda  pprefix,x			; step to next possible prefix
		beq  ++
	+	inx
		bne  -

	+	inx						; skip termination
		inx						; skip major
		inx						; skip minor
		ldy  #1
		lda  pprefix,x
		bne  --

		;; unknown prefix, may be a root-file handled by fs_sys
		;; which is not implemented
		;; (ldy  #MAJOR_SYS
		;; (ldx  #0
		;; (clc
		;; (rts
		
		lda  #lerr_nosuchfile
		sec
		rts						; unknown prefix

found:	iny
		tya
		clc
		adc  syszp    
		sta  syszp				; skip path prefix
		lda  pprefix+1,x		; get major
		tay  
		lda  pprefix+2,x
		tax
		clc
		rts	 ; return with Y=major, X=minor, c=0, [syszp]=file

		;; list of prefixes is hardcoded into the kernel for now
pprefix:
		.text "disk8"
		.byte 0, MAJOR_IEC,8
		.text "disk9"
		.byte 0, MAJOR_IEC,9
#ifdef HAVE_64NET2
		.text "net64"
		.byte 0, MAJOR_IEC,15
#endif
		.text "console"
		.byte 0, MAJOR_CONSOLE,0
		.text "pipe"
		.byte 0, MAJOR_PIPE,0
		.byte 0

;;; major tables
		;* fopen     - open file
		;fcmd      - do special commands on a file/device
		;fopendir  - open directory
		;fgetattr  - get file attributes
		;fsetattr  - set file attributes
		;* fclose    - close a file or directory
		;* fgetc     - get char
		;* fputc     - put char
		;fread     - get more than one char
		;fwrite    - put more than one char
		;fseek     - change read/write position
		;flock     - lock file (open it exclusive)
		;freaddir  - read one directory element

mtab_fopen equ [*]-2
		.word fs_pipe_fopen-1
		.word fs_iec_fopen-1
		.word fs_cons_fopen-1
		.word err_notimp-1		; fs_user
		;; .word err_notimp-1		; fs_sys
		
mtab_fgetc equ [*]-2
		.word fs_pipe_fgetc-1
		.word fs_iec_fgetc-1
		.word fs_cons_fgetc-1
		.word fs_user_fgetc-1
		;; .word err_notimp-1		; fs_sys
		
mtab_fputc equ [*]-2
		.word fs_pipe_fputc-1
		.word fs_iec_fputc-1
		.word fs_cons_fputc-1
		.word fs_user_fputc-1
		;; .word err_notimp-1		; fs_sys
		
mtab_fclose equ [*]-2
		.word fs_pipe_fclose
		.word fs_iec_fclose
		.word fs_cons_fclose
		.word fs_user_fclose
		;; .word err_notimp		; fs_sys
		
mtab_fcmd equ [*]-2
		.word err_notimp-1		; fs_pipe
		.word fs_iec_fcmd-1
		.word err_notimp-1		; fs_cons
		.word err_notimp-1		; fs_user
		;; .word err_notimp-1		; fs_sys
		
mtab_fopendir equ [*]-2
		.word err_notimp-1		; fs_pipe
		.word fs_iec_fopendir-1
		.word err_notimp-1		; fs_cons
		.word err_notimp-1		; fs_user
		;; .word err_notimp-1		; fs_sys
		
mtab_freaddir equ [*]-2
		.word err_notimp-1		; fs_pipe
		.word fs_iec_freaddir-1
		.word err_notimp-1		; fs_cons
		.word err_notimp-1		; fs_user
		;; .word err_notimp-1		; fs_sys

		;; function: resolve_fileno
		;; get SMB that corresponds to a given fileno
		;;  < X=fileno
		;;  > syszp=SMB, syszp+2=SMB-ID, Y=major*2, X=minor
		;;  > syszp+3=fileno
		;;  > c=error (A=errorcode)
		;; changes: syszp(0,1,2,3)
		;; changes: tmpzp(0,1,2,3,4,5,6,7)
		
resolve_fileno:
#ifndef ALWAYS_SZU
		sei
		ldy  lk_ipid
		lda  #tstatus_szu
		ora  lk_tstatus,y
		sta  lk_tstatus,y
		cli
#endif
		stx  syszp+3
		cpx  #MAX_FILES
		bcs  err_illfileno
		txa
		adc  #tsp_ftab
		tay
		lda  (lk_tsp),y
		beq  err_illfileno
		sta  syszp+2
		tax
		jsr  get_smbptr
		bcs  err_illfileno		; shoud be kernel-panic
		ldy  #1
		lda  (syszp),y			; major number of used device
		tax
		dey
		lda  (syszp),y
		asl  a
		tay
		rts ; return with syszp=SMB, syszp+2=SMB-ID, Y=major*2, X=minor
		    ;             syszp+3=fileno

err_illfileno:
		sec
		lda  #lerr_illfileno
		rts

		;; function: alloc_pfd
		;; allocate slot in process' file-table
		;; < X = SMB-ID
		;; > X = fd
		;; changes: A,X,Y
		
alloc_pfd:		
		sei
		ldy  #tsp_ftab
	-	lda  (lk_tsp),y
		beq  +
		iny
		cpy  #tsp_ftab+MAX_FILES
		bne  -
		cli
		lda  #lerr_toomanyfiles
		jmp  catcherr
		
	+	txa
		sta  (lk_tsp),y
		cli
		tya
		sec
		sbc  #tsp_ftab
		tax
		clc
		rts
		
;;;******************************************************
		
		;; function: fopendir
		;; open directory for reading with freaddir
		;; < A/Y = filename
		;; > c=0 : X = fileno
		;; > c=1 : A = errno
		;; changes: tmpzp(0,1,2,3,4,5,6,7)
		;; calls: resolve_dev
		
fopendir:
		jsr  resolve_dev
		bcs  +
		tya
		asl  a
		tay
		sei
		lda  mtab_fopendir+1,y
		pha
		lda  mtab_fopendir,y
		pha
		rts

		;; function: fopen
		;; open file 
		;; < A/Y = filename
		;; < X = mode (fmode_ro, fmode_wo, fmode_rw, fmode_a)
		;; > c=0 : X = fileno
		;; > c=1 : A = errno
		;; changes: tmpzp(0,1,2,3,4,5,6,7)
		;; calls: resolve_dev
		
fopen:
		cpx  #fmode_a+1
		bcs  err_notimp
		jsr  resolve_dev
		bcs  +
		tya
		asl  a
		tay
		sei
		lda  mtab_fopen+1,y
		pha
		lda  mtab_fopen,y
		pha
		rts

err_notimp:
		lda  #lerr_notimp
	+ -	jmp  catcherr

		;; function: fdup
		;; duplicate fd
		;; < X = fileno
		;; > X = new fileno
		;; calls: ref_increment
		
fdup:
		jsr  resolve_fileno
		bcs  -
		ldx  syszp+2
		jsr  alloc_pfd
		bcs  -
		jsr  ref_increment
_clend:	
#ifndef ALWAYS_SZU
		sei
		ldy  lk_ipid
		lda  #$ff-tstatus_szu
		and  lk_tstatus,y
		sta  lk_tstatus,y
		cli
#endif
		clc
		rts

		;; function: fclose
		;; close file
		;; < X = fileno, c=error (A=code)
		;; calls: resolve_fileno
		;; calls: smb_free
		;; changes: syszp(0,1)
		;; changes: tmpzp(0,1,2,3,4,5,6,7)
		
fclose:
		jsr  resolve_fileno
		bcs  -
		sei						; another atomic section (Grrr..)
		lda  mtab_fclose,y
		sta  _cljmp+1
		lda  mtab_fclose+1,y
		sta  _cljmp+2
		lda  syszp+3			; fileno
		clc
		adc  #tsp_ftab
		tay
		lda  #0
		sta  (lk_tsp),y			; clear fs in process' fs-table
		
		ldy  #fsmb_flags		; decrease reference counter
		lda  (syszp),y
		and  #fflags_read
		beq  ++
		ldy  #fsmb_rdcnt
		lda  (syszp),y
		sec
		sbc  #1
		bpl  +
		lda  #0					; kernel panic ?
	+	sta  (syszp),y
		
		ldy  #fsmb_flags
	+	lda  (syszp),y
		and  #fflags_write
		beq  ++
		ldy  #fsmb_wrcnt
		lda  (syszp),y
		sec
		sbc  #1
		bpl  +
		lda  #0					; kernel panic ?
	+	sta  (syszp),y

	+	ldy  #fsmb_rdcnt
		lda  (syszp),y
		ldy  #fsmb_wrcnt
		ora  (syszp),y
		bne  _clend				; don't close this file yet
		
		lda  syszp+2
		pha						; remember SMB-ID (if it must be freed)
		
_cljmp:	jsr  $0000

		pla
		beq  _clend
		tax
		jsr  smb_free
		jmp  _clend
		
		;; function: fputc
		;; put single byte to stream
		;; < X = fileno, c=blocking
		;; > c=0 : A = byte
		;;   c=1 : A = errno
		;; calls: resolve_fileno
		
fputc:
		sei
		sta  syszp+5			; data byte
		ror  syszp+4			; flag -> syszp+4
		txa
		pha
		tya
		pha
		jsr  resolve_fileno
		bcs  io_return_error
		lda  mtab_fputc+1,y
		pha
		lda  mtab_fputc,y
		pha
		rts


		;; function: fgetc
		;; get single byte from stream
		;; < X = fileno
		;; > c=0 : A = byte, c=blocking
		;;   c=1 : A = errno
		;; calls: resolve_fileno

fgetc:
		txa
		pha
		tya
		pha
		sei
		ror  syszp+4			; flag -> syszp+4
		jsr  resolve_fileno
		bcs  io_return_error
		lda  mtab_fgetc+1,y
		pha
		lda  mtab_fgetc,y
		pha
		;; syszp: 0/1=SMB-ptr, 2=SMB-ID, 3=fileno, 4=blocking-flag
		;; must return with io_return
		rts

io_return_error:
		sec
		SKIP_BYTE
io_return:
		clc
		sei
		sta  tmpzp
#ifndef ALWAYS_SZU
		ldx  lk_ipid
		lda  lk_tstatus,x
		and  #$ff-tstatus_szu
		sta  lk_tstatus,x
#endif
		pla
		tay
		pla
		tax
		lda  tmpzp
		cli
		bcs  +
		rts

	+	jmp  catcherr

		;; function: ref_increment
		;; increase reference counter of stream
		;; according to it's flags (readable/writeable)
		;; < syszp points to fs_smb
		;; changes: Y,A
		
ref_increment:	
		;; increase reference counter
		ldy  #fsmb_flags
		lda  (syszp),y
		and  #fflags_read
		beq  +
		ldy  #fsmb_rdcnt
		lda  (syszp),y
		adc  #1
		sta  (syszp),y
		ldy  #fsmb_flags
		
	+	lda  (syszp),y
		and  #fflags_write
		beq  +
		ldy  #fsmb_wrcnt
		lda  (syszp),y
		adc  #1
		sta  (syszp),y
	+	rts
		

	-	jmp  catcherr
		
		;; function: fcmd
		;; execute device specific command
		;; < A/Y = filename
		;;   X = command (fcmd_del)
		;; > c=0 : X = fileno
		;;   c=1 : A = errno
		;; changes: tmpzp(0,1,2,3,4,5,6,7)
		;; calls: resolve_dev

fcmd:	
		jsr  resolve_dev
		bcs  -
		tya
		asl  a
		tay
		sei
		lda  mtab_fcmd+1,y
		pha
		lda  mtab_fcmd,y
		pha
		rts		
		
		;; function: freaddir
		;; read single directory entry
		;; < X = fileno, A/Y = dir strcut
		;; > c=0 : A = byte, c=blocking
		;;   c=1 : A = errno
		;; calls: resolve_fileno

freaddir:
		sei
		sta  syszp+5
		sty  syszp+6
		ror  syszp+4			; flag -> syszp+4
		jsr  resolve_fileno
		bcs  -
		lda  mtab_freaddir+1,y
		pha
		lda  mtab_freaddir,y
		pha
		;; syszp: 0/1=SMB-ptr, 2=SMB-ID, 3=fileno, 4=blocking-flag
		;; 5/6=address of struct
		rts

		;; function: fgetdevice
		;; get device (major and minor numbers) of the device
		;; that is responsible for a give stream
		;; < X=stream ID
		;; > X/Y=minor/major
fgetdevice:
		jsr  resolve_fileno
		bcs  -
		tya
		lsr  a
#ifndef ALWAYS_SZU
		pha
		sei
		ldy  lk_ipid
		lda  #$ff-tstatus_szu
		and  lk_tstatus,y
		sta  lk_tstatus,y
		cli
		pla
#endif
		tay
		clc
		rts
		
;;;******************************************************

