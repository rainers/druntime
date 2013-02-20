;_ tlssup.asm
;  Win32 TLS support for DLL.
;
;  Copyright: Copyright Rainer Schuetze 2013
;  License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
;  Authors:   Rainer Schuetze
;

    public __tls_array
    public __tlsstart
    public __tlsend

__tls_array equ 2ch ; offset in TEB

.tls segment dword public 'tls'
__tlsstart:
.tls ends

.tls$ZZZ segment dword public 'tls'
__tlsend:
.tls$ZZZ ends

    end
