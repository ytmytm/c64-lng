#ifndef _IDENT_H
#define _IDENT_H

#ifndef _DATE_
#msg note: no date "(DD.MM.YY) " defined
#define _DATE_ ""
#endif
#begindef ident(string,number)
   .text "$ver: "
   .text "string "
   .byte 32
   .text "number "
   .byte 32
   .text _DATE_
   .text "$",0
#enddef

#endif
