;; for emacs: -*- MODE: asm; tab-width: 4; -*-
	
		;; **************************************************************
		;;  first task in the system  (init)
		;; **************************************************************

#include <fs.h>
#include <system.h>
#include <debug.h>
#include <kerrors.h>
#include MACHINE_H		

		.global init

out_of_mem:
		lda  #lerr_outofmem
		jmp  suicerrout

#include MACHINE(reboot.s)
				
init:							; former called microshell
		lda  #3
		jsr  set_zpsize			; use 3 bytes zeropage starting with userzp
		
		ldy  #tsp_pdmajor
		lda  #MAJOR_IEC
		sta  (lk_tsp),y
		iny
		lda  #8
		sta  (lk_tsp),y			; default device (8,0)

		jsr  console_open
		nop						; (need at least one working console)
		stx  console_fd

		;; print startup message
		
		ldy  #0
	-	lda  startup_txt,y
		beq  +
		jsr  cout
		iny
		bne  -
		
	+
		;; allocate temporary buffers
		ldx  lk_ipid
		ldy  #$00
		jsr  spalloc
		bcs  out_of_mem
		stx  tmp_page			; remember hi byte of page
		jmp  ploop

report_error_2:
report_error:
		jsr  print_error
		
ploop:
		lda  #"."
		jsr  cout
		jsr  readline
		lda  #$0a
		jsr  cout
		lda  userzp
		beq  ploop				; ignore empty lines

		;; parse commandline

		ldy  #0
		sty  userzp
		lda  (userzp),y
		beq  c_end
		iny
		beq  c_end
		cmp  #"L"
		beq  load_and_execute
		cmp  #"X"
		beq  reboot

		;; unknown command

c_end:	lda  #"?"
		jsr  cout
		lda  #$0a
		jsr  cout
		jmp  ploop

	-	iny
		beq  c_end
load_and_execute:		
		;; create new process (code loaded from disk)

		lda  (userzp),y
		beq  c_end
		cmp  #" "
		beq  -

		ldx  #0
	-	sta  appstruct+3,x
		iny
		lda  (userzp),y
		beq  +
		inx
		cpx  #28
		bne  -
		jmp  c_end

	+	sta  appstruct+4,x
		sta  appstruct+5,x
		sta  appstruct+6,x

		lda  console_fd
		sta  appstruct+0		; childs stdin
		sta  appstruct+1		; childs stdout
		sta  appstruct+2		; childs stderr
		
		;; fork_to child process
		lda  #<appstruct
		ldy  #>appstruct
		jsr  forkto
		bcs  report_error_2
		
		;; close console stream and try to open new one

		ldx  console_fd
		jsr  fclose

		jsr  console_open
		bcc  +
		ldx  #$ff
	+	stx  console_fd

		;; check for finished child processes

	-	ldx  #<wait_struct		; blocking if there is no console left
		ldy  #>wait_struct
		jsr  wait				; look for terminated child
		bcs  jploop				; carry always means lerr_tryagain (A not set)

	+	lda  console_fd
		bpl  +
		jsr  console_open
		bcs  -
		stx  console_fd
		
	+	pha
		ldy  #0
	-	lda  child_message_txt,y
		beq  +
		jsr  cout
		iny
		bne  -
		
	+	pla
		jsr  hex2cons
		lda  #" "
		jsr  cout
		ldy  #0
	-	lda  wait_struct,y
		jsr  hex2cons
		iny
		cpy  #7
		bne  -
		lda  #$0a
		jsr  cout

jploop:	
		jmp  ploop


;;; *******************************************

		;; read line from keyboard (not stdin)
		
readline:
		lda  #0
		sta  userzp
		lda  tmp_page
		sta  userzp+1

		;; wait for incomming char
		
	-	ldx  console_fd
		sec
		jsr  fgetc
		bcs  -					; (ignore EOF)

		;; got a valid char

		cmp  #$0a
		beq  read_return
		cmp  #32
		bcc  -					; illegal char (read again)
		ldy  #0
		sta  (userzp),y			; store char and echo to console
		jsr  cout
		inc  userzp
		bne  -
		dec  userzp
		jmp  -					; (beware of bufferoverflows)
				
read_return:
		ldy  #0
		tya
		sta  (userzp),y
		lda  userzp				; return length of string
		rts		

hex2cons:
		pha
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		jsr  +
		pla
		and  #15
	+	tax
		lda  hextab,x
cout:	sec
		ldx  console_fd
		jmp  fputc
		

hextab:	.text "0123456789abcdef"
				
child_message_txt:
		.byte $0a
		.asc "cHILD TERMINATED : \0"

console_fd:		.buf 1
		
wait_struct:	.buf 7				; 7 bytes

appstruct:		
		.byte 0,0,0	
		.buf  32

;;; strings

startup_txt:	.text $0a,"Init v0.1",$0a,$00
tmp_page:		.buf 1
