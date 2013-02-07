# patched to work under windows aswell
#
# This makefile is designed to be run by gnu make.
# The default make program on FreeBSD 8.1 is not gnu make; to install gnu make:
#    pkg_add -r gmake
# and then run as gmake rather than make.

QUIET:=@

OS:=
uname_S:=$(shell uname -s)
ifeq (Darwin,$(uname_S))
	OS:=osx
endif
ifeq (Linux,$(uname_S))
	OS:=linux
endif
ifeq (FreeBSD,$(uname_S))
	OS:=freebsd
endif
ifeq (OpenBSD,$(uname_S))
	OS:=openbsd
endif
ifeq (Solaris,$(uname_S))
	OS:=solaris
endif
ifeq (SunOS,$(uname_S))
	OS:=solaris
endif
ifeq (,$(OS))
	$(error Unrecognized or unsupported OS for uname: $(uname_S))
endif
# normalize windows names, e.g. Windows_NT
ifeq (win,$(findstring win,$(OS)))
	OS:=win32
endif
ifeq (Win,$(findstring Win,$(OS)))
	OS:=win32
endif

DMD?=dmd

MKDIR=mkdir
GREP=grep

DOCDIR=doc
IMPDIR=import

MODEL=32
override PIC:=$(if $(PIC),-fPIC,)

DFLAGS=-m$(MODEL) $(OPTFLAGS) -w -Isrc -Iimport -property $(PIC) $(DMDEXTRAFLAGS)
UDFLAGS=-m$(MODEL) $(OPTFLAGS) -w -Isrc -Iimport -property $(PIC) $(DMDEXTRAFLAGS)
DMDDEP = # $(shell which $(DMD))
DDOCFLAGS=-m$(MODEL) -c -w -o- -Isrc -Iimport

ifeq ($(BUILD),debug)
	OPTFLAGS=-g
	CFLAGS += -g
else
	OPTFLAGS=-O -release -inline
endif

ifeq (osx,$(OS))
    ASMFLAGS =
else
    ASMFLAGS = -Wa,--noexecstack
endif

ifeq (cl.exe,$(findstring cl.exe,$(CC)))
	CFLAGS_O = $(subst -g,/Z7,$(CFLAGS)) -Fo
#	OPTFLAGS := $(subst -g,,$(OPTFLAGS))  # no debug info yet
else
	CFLAGS_O = $(CFLAGS) $(PIC) -o
endif
	
ifeq (/,findstring /,$(DMD))
	DMDDEP = $(shell which $(DMD))
else
	DMDDEP = $(DMD)
endif

OBJDIR=obj/$(MODEL)
DRUNTIME_BASE=druntime-$(OS)$(MODEL)
ifeq (win32,$(OS))
	DRUNTIME=$(LIBDIR)/$(DRUNTIME_BASE).lib
else
	DRUNTIME=$(LIBDIR)/lib$(DRUNTIME_BASE).a
endif

DOCFMT=-version=CoreDdoc

include mak/posix.mak

SRC_D_MODULES_POSIX = \
	core/sys/freebsd/execinfo \
	core/sys/freebsd/sys/event \
	\
	core/sys/posix/signal \
	core/sys/posix/sys/select \
	core/sys/posix/sys/socket \
	core/sys/posix/sys/stat \
	core/sys/posix/sys/wait \
	core/sys/posix/netdb \
	core/sys/posix/sys/ioctl \
	core/sys/posix/sys/utsname \
	core/sys/posix/netinet/in_ \
	\
	rt/alloca \
	rt/cmath2 \
	rt/deh2 \

SRC_D_MODULES_WIN = \
	core/sys/windows/dll \
	core/sys/windows/threadaux \
	core/sys/windows/dbghelp \
	core/sys/windows/stacktrace \
	core/sys/windows/windows \

SRC_D_MODULES_WIN32 = \
	rt/deh \

SRC_D_MODULES_WIN32ms = \
	rt/alloca \
	rt/cmath2 \
	rt/deh \

SRC_D_MODULES_WIN64 = \
	rt/alloca \
	rt/cmath2 \
	rt/deh2 \

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32	 and
#       minit.asm is not used by dmd for Linux

OBJS:= $(OBJDIR)/errno_c.o $(OBJDIR)/threadasm.o $(OBJDIR)/complex.o
ifeq (win32,$(OS))
    SRC_D_MODULES += $(SRC_D_MODULES_WIN) $(SRC_D_MODULES_WIN$(MODEL))
    O = obj
    DOTEXE = .exe
    OBJS = $(OBJDIR)/errno_c.obj $(OBJDIR)/complex.obj
    ifeq ($(MODEL),32)
	    OBJS += src\rt\minit.obj
	endif
    ifeq ($(MODEL),32ms)
	    OBJS += src\rt\minit_coff.obj
    endif
else
    SRC_D_MODULES += $(SRC_D_MODULES_POSIX)
    DOTEXE =
    O = o
    OBJS= $(OBJDIR)/errno_c.o $(OBJDIR)/threadasm.o $(OBJDIR)/complex.o
endif


######################## All of'em ##############################

target : import copy $(DRUNTIME) doc

######################## Doc .html file generation ##############################

doc: $(DOCS)

$(DOCDIR)/object.html : src/object_.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $<

$(DOCDIR)/core_%.html : src/core/%.di
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $<

$(DOCDIR)/core_%.html : src/core/%.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $<

$(DOCDIR)/core_sync_%.html : src/core/sync/%.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $<

######################## Header .di file generation ##############################

import: $(IMPORTS)

$(IMPDIR)/core/sync/%.di : src/core/sync/%.d
	@mkdir -p `dirname $@`
	$(DMD) -m$(MODEL) -c -o- -Isrc -Iimport -Hf$@ $<

######################## Header .di file copy ##############################

copy: $(COPY)

$(IMPDIR)/%.di : src/%.di
	@mkdir -p `dirname $@`
	cp $< $@

$(IMPDIR)/%.d : src/%.d
	@mkdir -p `dirname $@`
	cp $< $@

ifeq (win32,$(OS))
# building on windows fails, but file is still generated
$(IMPDIR)/core/sys/freebsd/%.di : src/core/sys/freebsd/%.di
	-$(DMD) -m$(MODEL) -c -d -o- -Isrc -Iimport -Hf$@ $<
endif

################### C/ASM Targets ############################

$(OBJDIR)/%.$O : src/rt/%.c
	@$(MKDIR) -p $(OBJDIR)
	$(CC) -c $(CFLAGS_O)$@ $<

$(OBJDIR)/errno_c.$O : src/core/stdc/errno.c
	@$(MKDIR) -p $(OBJDIR)
	$(CC) -c $(CFLAGS_O)$@ $<

$(OBJDIR)/threadasm.o : src/core/threadasm.S
	@mkdir -p $(OBJDIR)
	$(CC) $(ASMFLAGS) -c $(CFLAGS) $< -o$@

src\rt\minit.obj : src\rt\minit.asm
	ml -c /omf /D_WIN32 /Fo$@ src\rt\minit.asm

src\rt\minit_coff.obj : src\rt\minit.asm
	ml -c /D_WIN32 /DCOFF /Fo$@ src\rt\minit.asm

################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS) posix.mak $(DMDDEP)
	$(DMD) -lib -of$(DRUNTIME) -Xf$(JSONDIR)\druntime.json $(DFLAGS) $(SRCS) $(OBJS)

UT_MODULES:=$(patsubst src/%.d,$(OBJDIR)/%,$(SRCS))

unittest : $(UT_MODULES) $(DRUNTIME) $(OBJDIR)/emptymain.d
unittest : $(addsuffix $(DOTEXE),$(addprefix $(OBJDIR)/,$(SRC_D_MODULES))) $(OBJDIR)/testall$(DOTEXE) 
	@echo done

ifeq ($(OS),freebsd)
DISABLED_TESTS =
else
DISABLED_TESTS =
endif

$(addprefix $(OBJDIR)/,$(DISABLED_TESTS)) :
	@echo $@ - disabled

$(OBJDIR)/%$(DOTEXE) : src/%.d $(DRUNTIME) $(OBJDIR)/emptymain.d
ifeq (win32,$(OS))
	@if $(GREP) -q unittest $< ; then \
	echo Testing $@ && \
	$(DMD) $(UDFLAGS) -version=druntime_unittest -unittest $(subst /,\\,-of$@ -map $@.map $(OBJDIR)/emptymain.d) $< -debuglib=$(DRUNTIME_BASE) -defaultlib=$(DRUNTIME_BASE) && \
	$(RUN) $@ ; \
	else echo Skipping $< ; \
	fi
else
	@$(DMD) $(UDFLAGS) -version=druntime_unittest -unittest -of$@ $(OBJDIR)/emptymain.d $< -L-Llib -debuglib=$(DRUNTIME_BASE) -defaultlib=$(DRUNTIME_BASE)
# make the file very old so it builds and runs again if it fails
	@touch -t 197001230123 $@
# run unittest in its own directory
	@$(RUN) $@
# succeeded, render the file new again
	@touch $@
endif	

$(OBJDIR)/testall$(DOTEXE) : $(SRCS) $(DRUNTIME) $(OBJDIR)/emptymain.d
	@echo Testing $@
ifeq (win32,$(OS))
	@$(DMD) $(UDFLAGS) -version=druntime_unittest -unittest $(subst /,\,-of$@ -map $@.map $(OBJDIR)/emptymain.d) $(SRCS) -debuglib=$(DRUNTIME_BASE) -defaultlib=$(DRUNTIME_BASE)
	@$(RUN) $@
else
	$(QUIET)$(DMD) $(UDFLAGS) -version=druntime_unittest -unittest -of$@ $(OBJDIR)/emptymain.d $< -L-Llib -debuglib=$(DRUNTIME_BASE) -defaultlib=$(DRUNTIME_BASE)
# make the file very old so it builds and runs again if it fails
	@touch -t 197001230123 $@
# run unittest in its own directory
	$(QUIET)$(RUN) $@
# succeeded, render the file new again
	@touch $@
endif	

$(OBJDIR)/emptymain.d :
	@$(MKDIR) -p $(OBJDIR)
ifeq (cmd.exe,$(findstring $(SHELL),cmd.exe))
	@echo void main(){} >$@
else
	@echo 'void main(){}' >$@
endif

detab:
	detab $(MANIFEST)
	tolf $(MANIFEST)

zip: druntime.zip

druntime.zip: $(MANIFEST) $(DOCS) $(IMPORTS)
	rm -rf $@
	zip $@ $^

install: druntime.zip
	unzip -o druntime.zip -d /dmd2/src/druntime

clean:
	rm -rf obj lib $(IMPDIR) $(DOCDIR) druntime.zip
