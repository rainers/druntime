;_ minit.asm
;  Module initialization support.
;
;  Copyright: Copyright Digital Mars 2000 - 2010.
;  License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
;  Authors:   Walter Bright
;
;           Copyright Digital Mars 2000 - 2010.
;  Distributed under the Boost Software License, Version 1.0.
;     (See accompanying file LICENSE or copy at
;           http://www.boost.org/LICENSE_1_0.txt)
;
include macros.asm

ifdef _WIN32
  DATAGRP      EQU     FLAT
else
  DATAGRP      EQU     DGROUP
endif

; Provide a default resolution for weak extern records, no way in C
; to define an omf symbol with a specific value
public __nullext
__nullext   equ 0

; This bit of assembler is needed because, from C or D, one cannot
; specify the names of data segments. Why does this matter?
; All the ModuleInfo pointers are placed into a segment named 'FM'.
; The order in which they are placed in 'FM' is arbitrarily up to the linker.
; In order to walk all the pointers, we need to be able to find the
; beginning and the end of the 'FM' segment.
; This is done by bracketing the 'FM' segment with two other, empty,
; segments named 'FMB' and 'FME'. Since this module is the only one that
; ever refers to 'FMB' and 'FME', we get to control the order in which
; these segments appear relative to 'FM' by using a GROUP statement.
; So, we have in memory:
;   FMB empty segment
;   FM  contains all the pointers
;   FME empty segment
; and finding the limits of FM is as easy as taking the address of FMB
; and the address of FME.

; These segments bracket FM, which contains the list of ModuleInfo pointers
FMB     segment dword use32 public 'DATA'
FMB     ends
FM      segment dword use32 public 'DATA'
FM      ends
FME     segment dword use32 public 'DATA'
FME     ends

; This leaves room in the _fatexit() list for _moduleDtor()
XOB     segment dword use32 public 'BSS'
XOB     ends
XO      segment dword use32 public 'BSS'
    dd  ?
XO      ends
XOE     segment dword use32 public 'BSS'
XOE     ends

ifndef COFF
DGROUP         group   FMB,FM,FME
endif

; These segments bracket HP, which contains the "has pointer" data
HPB     segment dword use32 public 'DATA'
HPB     ends
HP      segment dword use32 public 'DATA'
HP      ends
HPE     segment dword use32 public 'DATA'
HPE     ends

ifndef COFF
DGROUP         group   HPB,HP,HPE
endif

; These segments bracket HP, which contains the "has pointer" data
HPTLSB  segment dword use32 public 'DATA'
HPTLSB  ends
HPTLS   segment dword use32 public 'DATA'
HPTLS   ends
HPTLSE  segment dword use32 public 'DATA'
HPTLSE  ends

ifndef COFF
DGROUP         group   HPTLSB,HPTLS,HPTLSE
endif

ifndef COFF
    extrn   __moduleinfo_array:near

    begcode minit

; extern (C) void _minit();
; Converts array of ModuleInfo pointers to a D dynamic array of them,
; so they can be accessed via D.
; Result is written to:
; extern (C) ModuleInfo[] _moduleinfo_array;

    public  __minit
__minit proc    near
    mov EDX,offset DATAGRP:FMB
    mov EAX,offset DATAGRP:FME
    mov dword ptr __moduleinfo_array+4,EDX
    sub EAX,EDX         ; size in bytes of FM segment
    shr EAX,2           ; convert to array length
    mov dword ptr __moduleinfo_array,EAX
    ret
__minit endp

    endcode minit
endif

    begcode hparea

; extern (C) void[] _hparea();
; returns the memory area containing "has pointer" info [address of data,TypeInfo]
; so they can be accessed via D.

    public  __hparea
__hparea proc    near
    mov EDX,offset DATAGRP:HPB
    mov EAX,offset DATAGRP:HPE
    sub EAX,EDX         ; size in bytes of FM segment
    ret
__hparea endp

    endcode hparea

    begcode tlshparea

; extern (C) void[] _tlshparea();
; returns the memory area containing "has pointer" info in TLS [tls offset of data,TypeInfo]
; so they can be accessed via D.

    public  __tlshparea
__tlshparea proc    near
    mov EDX,offset DATAGRP:HPTLSB
    mov EAX,offset DATAGRP:HPTLSE
    sub EAX,EDX         ; size in bytes of FM segment
    ret
__tlshparea endp

    endcode tlshparea

ifdef COFF
    extrn   __alldiv:near
    extrn   __aulldiv:near
    extrn   __allrem:near
    extrn   __aullrem:near
    
    begcode __ms_alldiv
    public  __ms_alldiv
__ms_alldiv proc    near
    push ECX
    push EBX
    push EDX
    push EAX
    call __alldiv
    ret
__ms_alldiv endp
    endcode __ms_alldiv
 
    begcode __ms_aulldiv
    public  __ms_aulldiv
__ms_aulldiv proc    near
    push ECX
    push EBX
    push EDX
    push EAX
    call __aulldiv
    ret
__ms_aulldiv endp
    endcode __ms_aulldiv
 
    begcode __ms_allrem
    public  __ms_allrem
__ms_allrem proc    near
    push ECX
    push EBX
    push EDX
    push EAX
    call __allrem
    ret
__ms_allrem endp
    endcode __ms_allrem

    begcode __ms_aallrem
    public  __ms_aullrem
__ms_aullrem proc    near
    push ECX
    push EBX
    push EDX
    push EAX
    call __aullrem
    ret
__ms_aullrem endp
    endcode __ms_aullrem

endif

    end
