#ifndef _KEYBOARD_H
#define _KEYBOARD_H

#define keyb_ctrl   %00000001
#define keyb_rshift %00000010
#define keyb_lshift %00000100
#define keyb_keys   %10000000

#define joy_up      %00000001
#define joy_down    %00000010
#define joy_left    %00000100
#define joy_right   %00001000
#define joy_fire    %00010000

#define keybuflen 16      ; size of keyboard buffer
#define	port_row CIA1_PRA ; selection of rows
#define	port_col CIA1_PRB ; status of columns

#ifdef C128
# define port_row2 VIC_KEYREG
#endif

#endif
