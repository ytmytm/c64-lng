#ifndef _IDENT_H
#define _IDENT_H

; RCS and Amiga compatible identification tag
#begindef ident(string,number)
   .text "$VER: "
   .text "string "
   .text "number "
   .text _DATE_
   .text "$",0
#enddef

#endif
