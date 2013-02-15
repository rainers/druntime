# Makefile to build D runtime library druntime.lib for Win32

MODEL=32

DMD=dmd

CC=dmc

DOCDIR=doc
IMPDIR=import

# DFLAGS=-m$(MODEL) -O -release -inline -w -Isrc -Iimport -property
DFLAGS=-m$(MODEL) -g -w -Isrc -Iimport -property
UDFLAGS=-m$(MODEL) -O -release -w -Isrc -Iimport -property
DDOCFLAGS=-c -w -o- -Isrc -Iimport

CFLAGS=

DRUNTIME_BASE=druntime
DRUNTIME=lib\$(DRUNTIME_BASE).lib
GCSTUB=lib\gcstub.obj

DOCFMT=-version=CoreDdoc

target : import copydir copy $(DRUNTIME) doc $(GCSTUB)

$(mak\COPY)
$(mak\DOCS)
$(mak\IMPORTS)
$(mak\MANIFEST)
$(mak\SRCS)

# modules used by the static library
SRCS_STATIC = \
#	src\core\dll_helper.d \
	src\rt\dmain2.d \
	src\rt\trace.d \
	src\rt\memory.d \
#	src\rt\cmain.d \
	src\rt\minfo.d

# modules used to build the shared library (symbols not exported, compiled with version=druntime_shared)
SRCS_SHARED = \
	src\rt\dllmain.d \
	src\rt\memory.d \
	src\rt\minfo.d

# modules needed to link against the shared library (compiled with version=druntime_sharedrtl)
SRCS_SHAREDRTL = \
	src\core\sys\windows\dllclient.d \
	src\rt\dmain2.d \
	src\rt\memory.d \
#	src\rt\cmain.d \
	src\rt\minfo.d

SRCS = $(SRCS_ANY) $(SRCS_STATIC)

OBJS_SHAREDRTL = \
#	lib\dll_helper.obj \
	lib\memory.obj \
	lib\cmain.obj \

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32 and
#       minit.asm is not used by dmd for Linux

OBJS= errno_c.obj complex.obj src\rt\minit.obj
OBJS_TO_DELETE= errno_c.obj complex.obj

######################## Doc .html file generation ##############################

doc: $(DOCS)

$(DOCDIR)\object.html : src\object_.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_atomic.html : src\core\atomic.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_bitop.html : src\core\bitop.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_cpuid.html : src\core\cpuid.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_demangle.html : src\core\demangle.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_exception.html : src\core\exception.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_math.html : src\core\math.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_memory.html : src\core\memory.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_runtime.html : src\core\runtime.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_simd.html : src\core\simd.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_thread.html : $(IMPDIR)\core\thread.di
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_time.html : src\core\time.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_vararg.html : src\core\vararg.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_barrier.html : src\core\sync\barrier.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_condition.html : src\core\sync\condition.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_config.html : src\core\sync\config.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_exception.html : src\core\sync\exception.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_mutex.html : src\core\sync\mutex.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_rwmutex.html : src\core\sync\rwmutex.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_semaphore.html : src\core\sync\semaphore.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

######################## Header .di file generation ##############################

import: $(IMPORTS)

$(IMPDIR)\core\sync\barrier.di : src\core\sync\barrier.d
	$(DMD) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\condition.di : src\core\sync\condition.d
	$(DMD) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\config.di : src\core\sync\config.d
	$(DMD) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\exception.di : src\core\sync\exception.d
	$(DMD) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\mutex.di : src\core\sync\mutex.d
	$(DMD) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\rwmutex.di : src\core\sync\rwmutex.d
	$(DMD) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\semaphore.di : src\core\sync\semaphore.d
	$(DMD) -c -o- -Isrc -Iimport -Hf$@ $**

######################## Header .di file copy ##############################

copydir: $(IMPDIR)
	mkdir $(IMPDIR)\core\stdc
	mkdir $(IMPDIR)\core\sys\freebsd\sys
	mkdir $(IMPDIR)\core\sys\linux\sys
	mkdir $(IMPDIR)\core\sys\osx\mach
	mkdir $(IMPDIR)\core\sys\posix\arpa
	mkdir $(IMPDIR)\core\sys\posix\net
	mkdir $(IMPDIR)\core\sys\posix\netinet
	mkdir $(IMPDIR)\core\sys\posix\sys
	mkdir $(IMPDIR)\core\sys\windows
	mkdir $(IMPDIR)\etc\linux

copy: $(COPY)

$(IMPDIR)\object.di : src\object.di
	copy $** $@

$(IMPDIR)\core\atomic.d : src\core\atomic.d
	copy $** $@

$(IMPDIR)\core\bitop.d : src\core\bitop.d
	copy $** $@

$(IMPDIR)\core\cpuid.d : src\core\cpuid.d
	copy $** $@

$(IMPDIR)\core\demangle.d : src\core\demangle.d
	copy $** $@

$(IMPDIR)\core\exception.d : src\core\exception.d
	copy $** $@

$(IMPDIR)\core\math.d : src\core\math.d
	copy $** $@

$(IMPDIR)\core\memory.d : src\core\memory.d
	copy $** $@

$(IMPDIR)\core\runtime.d : src\core\runtime.d
	copy $** $@

$(IMPDIR)\core\simd.d : src\core\simd.d
	copy $** $@

$(IMPDIR)\core\thread.di : src\core\thread.di
	copy $** $@

$(IMPDIR)\core\time.d : src\core\time.d
	copy $** $@

$(IMPDIR)\core\vararg.d : src\core\vararg.d
	copy $** $@

$(IMPDIR)\core\stdc\complex.d : src\core\stdc\complex.d
	copy $** $@

$(IMPDIR)\core\stdc\config.d : src\core\stdc\config.d
	copy $** $@

$(IMPDIR)\core\stdc\ctype.d : src\core\stdc\ctype.d
	copy $** $@

$(IMPDIR)\core\stdc\errno.d : src\core\stdc\errno.d
	copy $** $@

$(IMPDIR)\core\stdc\fenv.d : src\core\stdc\fenv.d
	copy $** $@

$(IMPDIR)\core\stdc\float_.d : src\core\stdc\float_.d
	copy $** $@

$(IMPDIR)\core\stdc\inttypes.d : src\core\stdc\inttypes.d
	copy $** $@

$(IMPDIR)\core\stdc\limits.d : src\core\stdc\limits.d
	copy $** $@

$(IMPDIR)\core\stdc\locale.d : src\core\stdc\locale.d
	copy $** $@

$(IMPDIR)\core\stdc\math.d : src\core\stdc\math.d
	copy $** $@

$(IMPDIR)\core\stdc\signal.d : src\core\stdc\signal.d
	copy $** $@

$(IMPDIR)\core\stdc\stdarg.d : src\core\stdc\stdarg.d
	copy $** $@

$(IMPDIR)\core\stdc\stddef.d : src\core\stdc\stddef.d
	copy $** $@

$(IMPDIR)\core\stdc\stdint.d : src\core\stdc\stdint.d
	copy $** $@

$(IMPDIR)\core\stdc\stdio.d : src\core\stdc\stdio.d
	copy $** $@

$(IMPDIR)\core\stdc\stdlib.d : src\core\stdc\stdlib.d
	copy $** $@

$(IMPDIR)\core\stdc\string.d : src\core\stdc\string.d
	copy $** $@

$(IMPDIR)\core\stdc\tgmath.d : src\core\stdc\tgmath.d
	copy $** $@

$(IMPDIR)\core\stdc\time.d : src\core\stdc\time.d
	copy $** $@

$(IMPDIR)\core\stdc\wchar_.d : src\core\stdc\wchar_.d
	copy $** $@

$(IMPDIR)\core\stdc\wctype.d : src\core\stdc\wctype.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\dlfcn.d : src\core\sys\freebsd\dlfcn.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\execinfo.d : src\core\sys\freebsd\execinfo.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\sys\event.d : src\core\sys\freebsd\sys\event.d
	copy $** $@

$(IMPDIR)\core\sys\linux\config.d : src\core\sys\linux\config.d
	copy $** $@

$(IMPDIR)\core\sys\linux\dlfcn.d : src\core\sys\linux\dlfcn.d
	copy $** $@

$(IMPDIR)\core\sys\linux\elf.d : src\core\sys\linux\elf.d
	copy $** $@

$(IMPDIR)\core\sys\linux\epoll.d : src\core\sys\linux\epoll.d
	copy $** $@

$(IMPDIR)\core\sys\linux\execinfo.d : src\core\sys\linux\execinfo.d
	copy $** $@

$(IMPDIR)\core\sys\linux\link.d : src\core\sys\linux\link.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\signalfd.d : src\core\sys\linux\sys\signalfd.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\xattr.d : src\core\sys\linux\sys\xattr.d
	copy $** $@

$(IMPDIR)\core\sys\osx\execinfo.d : src\core\sys\osx\execinfo.d
	copy $** $@

$(IMPDIR)\core\sys\osx\pthread.d : src\core\sys\osx\pthread.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\kern_return.d : src\core\sys\osx\mach\kern_return.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\port.d : src\core\sys\osx\mach\port.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\semaphore.d : src\core\sys\osx\mach\semaphore.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\thread_act.d : src\core\sys\osx\mach\thread_act.d
	copy $** $@

$(IMPDIR)\core\sys\posix\arpa\inet.d : src\core\sys\posix\arpa\inet.d
	copy $** $@

$(IMPDIR)\core\sys\posix\config.d : src\core\sys\posix\config.d
	copy $** $@

$(IMPDIR)\core\sys\posix\dirent.d : src\core\sys\posix\dirent.d
	copy $** $@

$(IMPDIR)\core\sys\posix\dlfcn.d : src\core\sys\posix\dlfcn.d
	copy $** $@

$(IMPDIR)\core\sys\posix\fcntl.d : src\core\sys\posix\fcntl.d
	copy $** $@

$(IMPDIR)\core\sys\posix\grp.d : src\core\sys\posix\grp.d
	copy $** $@

$(IMPDIR)\core\sys\posix\inttypes.d : src\core\sys\posix\inttypes.d
	copy $** $@

$(IMPDIR)\core\sys\posix\netdb.d : src\core\sys\posix\netdb.d
	copy $** $@

$(IMPDIR)\core\sys\posix\net\if_.d : src\core\sys\posix\net\if_.d
	copy $** $@

$(IMPDIR)\core\sys\posix\netinet\in_.d : src\core\sys\posix\netinet\in_.d
	copy $** $@

$(IMPDIR)\core\sys\posix\netinet\tcp.d : src\core\sys\posix\netinet\tcp.d
	copy $** $@

$(IMPDIR)\core\sys\posix\poll.d : src\core\sys\posix\poll.d
	copy $** $@

$(IMPDIR)\core\sys\posix\pthread.d : src\core\sys\posix\pthread.d
	copy $** $@

$(IMPDIR)\core\sys\posix\pwd.d : src\core\sys\posix\pwd.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sched.d : src\core\sys\posix\sched.d
	copy $** $@

$(IMPDIR)\core\sys\posix\semaphore.d : src\core\sys\posix\semaphore.d
	copy $** $@

$(IMPDIR)\core\sys\posix\setjmp.d : src\core\sys\posix\setjmp.d
	copy $** $@

$(IMPDIR)\core\sys\posix\signal.d : src\core\sys\posix\signal.d
	copy $** $@

$(IMPDIR)\core\sys\posix\stdio.d : src\core\sys\posix\stdio.d
	copy $** $@

$(IMPDIR)\core\sys\posix\stdlib.d : src\core\sys\posix\stdlib.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\ioctl.d : src\core\sys\posix\sys\ioctl.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\ipc.d : src\core\sys\posix\sys\ipc.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\mman.d : src\core\sys\posix\sys\mman.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\select.d : src\core\sys\posix\sys\select.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\shm.d : src\core\sys\posix\sys\shm.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\socket.d : src\core\sys\posix\sys\socket.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\stat.d : src\core\sys\posix\sys\stat.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\statvfs.d : src\core\sys\posix\sys\statvfs.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\time.d : src\core\sys\posix\sys\time.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\types.d : src\core\sys\posix\sys\types.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\uio.d : src\core\sys\posix\sys\uio.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\un.d : src\core\sys\posix\sys\un.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\wait.d : src\core\sys\posix\sys\wait.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\utsname.d : src\core\sys\posix\sys\utsname.d
	copy $** $@

$(IMPDIR)\core\sys\posix\termios.d : src\core\sys\posix\termios.d
	copy $** $@

$(IMPDIR)\core\sys\posix\time.d : src\core\sys\posix\time.d
	copy $** $@

$(IMPDIR)\core\sys\posix\ucontext.d : src\core\sys\posix\ucontext.d
	copy $** $@

$(IMPDIR)\core\sys\posix\unistd.d : src\core\sys\posix\unistd.d
	copy $** $@

$(IMPDIR)\core\sys\posix\utime.d : src\core\sys\posix\utime.d
	copy $** $@

$(IMPDIR)\core\sys\windows\dbghelp.d : src\core\sys\windows\dbghelp.d
	copy $** $@

$(IMPDIR)\core\sys\windows\dll.d : src\core\sys\windows\dll.d
	copy $** $@

$(IMPDIR)\core\sys\windows\dllclient.d : src\core\sys\windows\dllclient.d
	copy $** $@

$(IMPDIR)\core\sys\windows\dllshared.d : src\core\sys\windows\dllshared.d
	copy $** $@

$(IMPDIR)\core\sys\windows\stacktrace.d : src\core\sys\windows\stacktrace.d
	copy $** $@

$(IMPDIR)\core\sys\windows\threadaux.d : src\core\sys\windows\threadaux.d
	copy $** $@

$(IMPDIR)\core\sys\windows\tls.d : src\core\sys\windows\tls.d
	copy $** $@

$(IMPDIR)\core\sys\windows\windows.d : src\core\sys\windows\windows.d
	copy $** $@

$(IMPDIR)\etc\linux\memoryerror.d : src\etc\linux\memoryerror.d
	copy $** $@

################### C\ASM Targets ############################

errno_c.obj : src\core\stdc\errno.c
	$(CC) -c $(CFLAGS) src\core\stdc\errno.c -oerrno_c.obj

complex.obj : src\rt\complex.c
	$(CC) -c $(CFLAGS) src\rt\complex.c

errno_c_shared.obj : src\core\stdc\errno.c
	$(CC) -c -NL $(CFLAGS) src\core\stdc\errno.c -o$@

complex_shared.obj : src\rt\complex.c
	$(CC) -c -NL $(CFLAGS) src\rt\complex.c -o$@

src\rt\minit.obj : src\rt\minit.asm
	$(CC) -c $(CFLAGS) src\rt\minit.asm

################### gcstub generation #########################

$(GCSTUB) : src\gcstub\gc.d win$(MODEL).mak
	$(DMD) -c -of$(GCSTUB) src\gcstub\gc.d $(DFLAGS)

################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS) win$(MODEL).mak
	$(DMD) -lib -of$(DRUNTIME) -Xfdruntime.json $(DFLAGS) $(SRCS) $(OBJS)

################### shared Library modules #####################

IMPLIB = c:\l\dmc\bin\implib
DMLIB = c:\l\dmc\bin\lib
SHARED_DEF = src\shared\druntime_shared.def
# where to find snn.lib
SNN_LIB = ..\lib\snn.lib
SND_LIB = ..\lib\snd.lib
# (relative to subfolder snn)
SNN_LIB2 = ..\$(SNN_LIB)
SND_LIB2 = ..\$(SND_LIB)

OBJS_SHARED = errno_c_shared.obj complex_shared.obj src\rt\minit.obj snn\tlsseg.obj

GENEXP = ..\windows\bin\genexp

SHARED_DFLAGS    = -g -version=druntime_shared $(DFLAGS) -defaultlib=$(SND_LIB) -debuglib=$(SND_LIB) -L/DELEXE
SHAREDRTL_DFLAGS = -g -version=druntime_sharedrtl $(DFLAGS)

druntime_dll: lib\druntime.obj lib\druntime_dynamic.lib $(OBJS_SHAREDRTL)

lib\druntime_export.obj lib\druntime_export.symbols: $(SRCS_ANY) win32.mak
	$(DMD) -c -of$@ -exportall=lib\druntime_export.symbols $(SHARED_DFLAGS) $(SRCS_ANY)

lib\druntime_export_symbols.d : lib\druntime_export.symbols
	+$(GENEXP) $** > $@

lib\druntime_export_symbols.obj : lib\druntime_export_symbols.d
	$(DMD) -c -of$@ $**

lib\druntime_shared.dll: lib\druntime_export.obj $(SRCS_SHARED) $(SHARED_DEF) $(OBJS_SHARED) win32.mak
	$(DMD) -of$@ $(SHARED_DFLAGS) $(SRCS_SHARED) -map -L/MAP:FULL -L/XREF lib\druntime_export.obj $(SHARED_DEF) $(OBJS_SHARED)
	
lib\druntime_import.lib: lib\druntime_shared.dll
	$(IMPLIB) $@ $**

# these objs should not export symbols, and are used for each binary using druntime_shared.dll
lib\druntime_shared.lib: lib\druntime_import.lib $(SRCS_SHAREDRTL) lib\druntime_export_symbols.obj win32.mak
	$(DMD) -lib -of$@ $(SHAREDRTL_DFLAGS) $(SRCS_SHAREDRTL) lib\druntime_export_symbols.obj lib\druntime_import.lib

OBJS_SNN = \
#	ehinit \
	tlsseg

OBJS_SND = \
	cinit \
	clearbss \
	constart \
	dllstart \
	excptlst \
	exit \
	setargv \
	tlsdata \
	winstart

lib\snn_shared.lib: $(SNN_LIB) win32.mak
	if not exist snn\nul mkdir snn
	cd snn
	$(DMLIB) -x $(SNN_LIB2) $(OBJS_SNN)
	$(DMLIB) -x $(SND_LIB2) $(OBJS_SND)
	$(DMLIB) -c ..\lib\snn_shared.lib $(OBJS_SNN) $(OBJS_SND)
	cd ..

druntime_dll:
	+cd $(DRUNTIME) && $(MAKE) -f win32.mak target druntime_dll
	
dll: lib\druntime_shared.lib 
# lib\snn_shared.lib


DLL_FILES_TO_CLEAN = $(OBJS_SHAREDRTL) lib\druntime.obj lib\druntime_dynamic.lib

################### shared Library modules #####################

unittest : $(SRCS) $(DRUNTIME) src\unittest.d
	$(DMD) $(UDFLAGS) -L/co -version=druntime_unittest -unittest src\unittest.d $(SRCS) $(DRUNTIME) -debuglib=$(DRUNTIME) -defaultlib=$(DRUNTIME)

zip: druntime.zip

druntime.zip:
	del druntime.zip
	zip32 -ur druntime $(MANIFEST) $(DOCS) $(IMPDIR) src\rt\minit.obj

install: druntime.zip
	unzip -o druntime.zip -d \dmd2\src\druntime

clean:
	del $(DRUNTIME) $(OBJS_TO_DELETE) $(GCSTUB)
	rmdir /S /Q $(DOCDIR) $(IMPDIR)
