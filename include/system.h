#ifndef _SYSTEM_H
#define _SYSTEM_H

;// LNG-magic and version
#define LNG_MAGIC   $fffe
#define LNG_VERSION $0010

;// jumptab-addresses are adapted at runtime (by the code relocator)
;// (i want binary compatible apps on all supported machines)
#define lk_jumptab   $0200  ; (virtual) start address of kernel jumptable

;// system zeropage

#define lk_ipid        $02  ; IPID of current task
#define lk_timer       $03  ; time left for current task (in 1/64s)
#define lk_tsp         $04  ; pointer to task-superpage (16 bit)
#define lk_sleepcnt    $06  ; time till next wakeup (16 bit)
#define lk_locktsw     $08  ; >0 -> taskswitching disabled
#define lk_systic      $09  ; systic counter (1/64s)  (24 bit)
#define lk_sleepipid   $12  ; IPID of task to wakeup next
#define lk_cycletime   $13  ; sum of tslice of all running tasks
#define lk_cyclefactor $14  ; defines how tslice is calculated from priority

;// additional zp allocations start at $15 and
;// are defined in zp.h !

;// nmizp - only used by NMI-handler 

;// irqzp - may be used by IRQ-handler or between sei/.../cli (=1)
;// tmpzp - may be used between jsr locktsw/.../jsr unlocktsw (=2) or (1)
;// syszp - may be used, when tstatus_szu set or (1) or (2)

;// userzp - use as many bytes as enabled with jsr set_zpsize in a task

;// NMI or IRQ handler have dedicated zeropage areas, they must not modify
;// any other bytes of the zeropage (not even indirect by calling other
;// routines)

#define nmizp          $68  ; 8 bytes for NMI handler
#define irqzp          $60  ; 8 bytes for IRQ handler(s)
#define tmpzp          $70  ; 8 bytes for atomic routines
#define syszp          $78  ; 8 bytes for reentrant system/library routines
#define userzp         $80  ; up to 64 bytes for the user

;// per task data structures (offset to task-superpage)

;//   parts that are initialized with zero
#define tsp_time    $00 ; (5 bytes)
#define tsp_wait0   $05
#  define waitc_sleeping $01 ; waiting for wakeup
#  define waitc_wait     $02 ; waiting for exitcode of child
#  define waitc_zombie   $03 ; waiting for parent reading exitcode (zombie)
#  define waitc_smb      $04 ; waiting for free SMB
#  define waitc_imem     $05 ; waiting for internal memory page
#  define waitc_stream   $06 ; waiting for stream-data
#  define waitc_semaphore $07 ; waiting for system semaphore
#  define waitc_brkpoint $08 ; waiting for cont. (hit breakpoint)
#  define waitc_conskey  $09 ; waiting for console key
#define tsp_wait1   $06
#define tsp_semmap  $07 ; 5 bytes (40 semaphores)
#define tsp_signal_vec $0c ; 8 16bit signal vectors (16 bytes total)
#  define sig_chld       0   ; child terminated
#  define sig_term       1   ; stop-key (CTRL-C, or kill without argument)
#  define sig_kill       9   ; force process to call suicide routine
#define tsp_zpsize  $1c ; must be the last zero initialized item here !  (->addtask.s)
#define tsp_ftab    $1d ; MAX_FILES bytes file-table (fileno to SMB-ID mapping)
#  define MAX_FILES      8
#define tsp_pdmajor $25 ; current device (major)
#define tsp_pdminor $26 ; current device (minor)
;//
#define tsp_pid     $27 ; (2 bytes)
#define tsp_ippid   $29 ; IPID of parent
#define tsp_stsize  $2a

#define tsp_syszp   $78
#define tsp_swap    $80

;// per task system data (not in tsp for faster access)
#define lk_tstatus   $c200
#  define tstatus_szu    $80  ; if task uses the syszp zeropage
#  define tstatus_susp   $40  ; if task is not getting CPU
#  define tstatus_nonmi  $20  ; if task has disabled NMI
#  define tstatus_nosig  $10  ; no signals / no kill (birth/death)
#  define tstatus_pri    $07  ; priority (value in the range of 1..7, not 0!!)
#define lk_tnextt    $c220
#define lk_tslice    $c240
#define lk_ttsp      $c260

;// system data
#define lk_memnxt    $c000  ; 256 bytes - 1 byte for each internal page
#define lk_memown    $c100  ; 256 bytes - 1 byte for each internal page
#  define memown_smb   $20
#  define memown_cache $21
#  define memown_sys   $22
#  define memown_modul $23
#  define memown_scr   $24
#  define memown_netbuf $25
#  define memown_none  $ff

#define lk_memmap    $c280  ; 32 bytes - 1 bit of each internal page
#define lk_semmap    $c2a0  ; 5 bytes (enough for 40 semaphores)
#  define lsem_irq1  0        ; byte 0, bit 0
#  define lsem_irq2  1        ; byte 0, bit 1
#  define lsem_irq3  2        ; byte 0, bit 2
#  define lsem_alert 3        ; byte 0, bit 3
#  define lsem_nmi   4        ; byte 0, bit 4
#  define lsem_iec   5        ; byte 0, bit 5  (access to IEC serial bus)
#define lk_nmidiscnt $c2a5  ; counts number of "nonmi" tasks
#define lk_taskcnt   $c2a6  ; counts number of tasks (16 bit)
#define lk_modroot   $c2a8  ; root of linked list of available modules (16bit)
#define lk_consmax   $c2aa  ; absolute number of consoles
#define lk_archtype  $c2ab  ; machine architecture
#  define larchf_type %00000011
#   define larch_c64  0
#   define larch_c128 1
#  define larchf_pal  %00100000
#  define larchf_reu  %01000000
#  define larchf_scpu %10000000
#define lk_timedive  $c2c0  ; exponent of time dic
#define lk_timedivm  $c2e0  ; mantisse of timediv

#define lk_smbmap    $c2c0  ; 32 bytes, bitmap of unused SMB-IDs
#define lk_smbpage   $c2e0  ; 32 bytes, base address of SMB-pages (hi byte)
                            ;// (byte 0 not used)
#endif

