#ifndef _CONSOLE_H
#define _CONSOLE_H

#include <config.h>
#include <system.h>
#include MACHINE_H
#include <zp.h>
		
#ifdef HAVE_REU
# include <reu.h>
#endif

#ifdef VIC_CONSOLE
;// defines for VIC console
# define screenA_base $400
# define screenB_base $800	
# define cursor  100
# define size_x  40
# define size_y  25
# define MAX_CONSOLES		2
#endif
#ifdef VDC_CONSOLE
;// defines for VDC console
# include <vdc.h>
# define FONT_ROM     $d800 ; font (2k)
# define CONSOLE_OFFS $1000 ; offset for first console - equal to font(s) size(s)
# define size_x  80
# define size_y  25
# define MAX_CONSOLES		6
#endif

#endif
