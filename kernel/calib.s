		;; calibrate delay loop (only for startup)

		;; should be the shortest possible delay available on all
		;; 6502-machines (i assume they all run at least at 1MHz)
		;; so the shortest delay would be JSR+RTS = 12탎
		;; the smallest (worst case) step we can do is INX+BNE = 5탎
		;; do get a accuracy of 90% in every case the time should be
		;; at least 10*5탎 = 50탎

		;; lets implement "delay_50us"

#include <config.h>

.global calibrate_delay

#  include MACHINE(calib.s)

		;; no calib for other systems yet
		;;   delay = value*5+26 cycles = 50탎

		;; function: calibrate_delay
		;; used to calibrate delay loops 
		;; well, seems not to work well this way
		;; hardcoding might be better
		;; changes: unknown

;simple version (without calibration) could look like that		
;calibrate_delay:
;		ldx  #<($10000 - 5)		; default values for 1MHz systems
;		ldy  #>($10000 - 5)		; ( 1MHz -> 5 )
;		stx  delay_calib_lo
;		sty  delay_calib_hi
;		rts
		
