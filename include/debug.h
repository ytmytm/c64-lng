;// addresses that can be altered (eg. incremented) for debugging

#ifndef _DEBUG_H
#define _DEBUG_H

#include <config.h>
#include MACHINE_H

;// "visible" addresses that maybe used for debugging

#ifdef C64
# define debug1       VIC_BC    ; foreground color
# define debug2       VIC_GC0   ; background color
# define debug3       $400      ; upper left corner of the screen
#endif

#endif
