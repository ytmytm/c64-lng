;// main configuration file

#ifndef _CONFIG_H
#define _CONFIG_H

# define ATARI
# define MACHINE_H <atari.h>
# define MACHINE(file) "atari/file"

;// Kernel error messages
;// ---------------------
;//   The functions "lkf_printerror" and "lkf_suicerrout" print a short
;//   message via printk. Normally just the error code is reported.
;//   If you want to have textual error messages add the following to
;//   the compile-flags (costs 444 bytes)

#define VERBOSE_ERROR

;// Multiple consoles
;// -----------------
;// startup with more than just one console, system needs at least 1k for
;// each additional console! (should better allocate memory on demand)
;// currently the functions keys are used to select and shift+commodore to
;// switch between consoles (this time just 2 consoles are available F1/F2)
;// (costs 1024+135=1159 bytes)
;// THIS IS UNSUPPORTED RIGHT NOW
;#define MULTIPLE_CONSOLES

;// Misc stuff
;// ----------
;// always_szu may save some memory (around 265 bytes), but usually
;// slows taskswitching down (up to 160us per taskswitch)

;#define ALWAYS_SZU


;//---------------------------------------------------------------------------
;// end of configurable section


#define ANTIC_CONSOLE

;// dummy
#define SPEED_MAX
#define SPEED_1MHZ

#endif
