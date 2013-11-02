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
INSTALL_DIR=../install

MKDIR=mkdir
GREP=grep

DOCDIR=doc
IMPDIR=import

MODEL:=default
ifneq (default,$(MODEL))
	MODEL_FLAG:=-m$(MODEL)
endif
override PIC:=$(if $(PIC),-fPIC,)

ifeq (osx,$(OS))
	DOTDLL:=.dylib
	DOTLIB:=.a
else
	DOTDLL:=.so
	DOTLIB:=.a
endif

DFLAGS=$(MODEL_FLAG) $(OPTFLAGS) -w -Isrc -Iimport $(PIC) $(DMDEXTRAFLAGS)
UDFLAGS=$(MODEL_FLAG) $(OPTFLAGS) -w -Isrc -Iimport $(PIC) $(DMDEXTRAFLAGS)
DDOCFLAGS=-c -w -o- -Isrc -Iimport -version=CoreDdoc

CFLAGS=$(MODEL_FLAG) -O $(PIC)
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
	CFLAGS_O = $(subst -g,/Z7,$(CFLAGS)) /Zl -Fo
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
DRUNTIMESO=lib/lib$(DRUNTIME_BASE).so
DRUNTIMESOOBJ=lib/lib$(DRUNTIME_BASE)so.o
DRUNTIMESOLIB=lib/lib$(DRUNTIME_BASE)so.a

DOCFMT=

include mak/COPY
COPY:=$(subst \,/,$(COPY))

include mak/DOCS
DOCS:=$(subst \,/,$(DOCS))

include mak/IMPORTS
IMPORTS:=$(subst \,/,$(IMPORTS))

include mak/MANIFEST
MANIFEST:=$(subst \,/,$(MANIFEST))

include mak/SRCS
SRCS:=$(subst \,/,$(SRCS))

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32	 and
#       minit.asm is not used by dmd for Linux

ifeq (win32,$(OS))
    SRC_D_MODULES += $(SRC_D_MODULES_WIN) $(SRC_D_MODULES_WIN$(MODEL))
    O = obj
    DOTEXE = .exe
    OBJS = $(OBJDIR)/errno_c.obj
    ifeq ($(MODEL),32)
	    OBJS += src\rt\minit.obj
	endif
    ifeq ($(MODEL),32ms)
#	    OBJS += src\rt\minit_coff.obj
    endif
else
    SRC_D_MODULES += $(SRC_D_MODULES_POSIX)
    DOTEXE =
    O = o
    OBJS= $(OBJDIR)/errno_c.o $(OBJDIR)/threadasm.o
endif

######################## All of'em ##############################

ifeq (linux,$(OS))
target : import copy dll $(DRUNTIME) doc
else
target : import copy $(DRUNTIME) doc
endif

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
	@$(MKDIR) -p $(dir $@).
	$(DMD) -c -o- -Isrc -Iimport -Hf$@ $<

######################## Header .di file copy ##############################

copy: $(COPY)

$(IMPDIR)/%.di : src/%.di
	@$(MKDIR) -p $(dir $@).
	cp $< $@

$(IMPDIR)/%.d : src/%.d
	@$(MKDIR) -p $(dir $@).
	cp $< $@

ifeq (win32,$(OS))
# building on windows fails, but file is still generated
$(IMPDIR)/core/sys/freebsd/%.di : src/core/sys/freebsd/%.di
	-$(DMD) -m$(MODEL) -c -d -o- -Isrc -Iimport -Hf$@ $<
endif

################### C/ASM Targets ############################

$(OBJDIR)/%.$O : src/rt/%.c
	@$(MKDIR) -p $(dir $@).
	$(CC) -c $(CFLAGS_O)$@ $<

$(OBJDIR)/errno_c.$O : src/core/stdc/errno.c
	@$(MKDIR) -p $(OBJDIR)
	$(CC) -c $(CFLAGS_O)$@ $<

$(OBJDIR)/threadasm.o : src/core/threadasm.S
	@$(MKDIR) -p $(OBJDIR)
	$(CC) $(ASMFLAGS) -c $(CFLAGS) $< -o$@

src\rt\minit.obj : src\rt\minit.asm
	ml -c /omf /D_WIN32 /Fo$@ src\rt\minit.asm

src\rt\minit_coff.obj : src\rt\minit.asm
	ml -c /D_WIN32 /DCOFF /Fo$@ src\rt\minit.asm

######################## Create a shared library ##############################

$(DRUNTIMESO) $(DRUNTIMESOLIB) dll: override PIC:=-fPIC
$(DRUNTIMESO) $(DRUNTIMESOLIB) dll: DFLAGS+=-version=Shared
dll: $(DRUNTIMESOLIB)

$(DRUNTIMESO): $(OBJS) $(SRCS)
	$(DMD) -shared -debuglib= -defaultlib= -of$(DRUNTIMESO) $(DFLAGS) $(SRCS) $(OBJS) -L-ldl

$(DRUNTIMESOLIB): $(OBJS) $(SRCS)
	$(DMD) -c -fPIC -of$(DRUNTIMESOOBJ) $(DFLAGS) $(SRCS)
	$(DMD) -lib -of$(DRUNTIMESOLIB) $(DRUNTIMESOOBJ) $(OBJS)

################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS) posix.mak $(DMDDEP)
	$(DMD) -lib -of$(DRUNTIME) -Xf$(JSONDIR)\druntime.json $(DFLAGS) $(SRCS) $(OBJS)

################### shared Library generation ##################
ADDITIONAL_TESTS:=test/init_fini test/exceptions
ADDITIONAL_TESTS+=$(if $(findstring $(OS),linux),test/shared,)

unittest : $(UT_MODULES) $(addsuffix /.run,$(ADDITIONAL_TESTS))
shared: $(LIBDIR)/$(DRUNTIME_BASE)_shared.dll

SDFLAGS = $(DFLAGS) -version=druntime_shared 
ifeq (win32,$(OS))
SDFLAGS += -exportall -defaultlib=msvcrt -L/DLL
endif

$(LIBDIR)/$(DRUNTIME_BASE)_shared.dll : $(OBJS) $(SRCS) win64.mak
	$(DMD) $(SDFLAGS) -of$@ src\rt\dllmain.d $(SRCS) $(OBJS) src\shared\dummy.def

################### unittests #########################

UT_MODULES:=$(patsubst src/%.d,$(OBJDIR)/%$(DOTEXE),$(SRCS))

unittest : $(UT_MODULES) $(DRUNTIME) $(OBJDIR)/emptymain.d
	@echo done

ifeq ($(OS),freebsd)
DISABLED_TESTS =
else
DISABLED_TESTS =
endif

$(addprefix $(OBJDIR)/,$(DISABLED_TESTS)) :
	@echo $@ - disabled

ifneq (linux,$(OS))

$(OBJDIR)/test_runner$(DOTEXE): $(OBJS) $(SRCS) src/test_runner.d
	$(DMD) $(UDFLAGS) -version=druntime_unittest -unittest -of$@ src/test_runner.d $(SRCS) $(OBJS) -debuglib= -defaultlib=

else

UT_DRUNTIME:=$(OBJDIR)/lib$(DRUNTIME_BASE)-ut$(DOTDLL)

$(UT_DRUNTIME): override PIC:=-fPIC
$(UT_DRUNTIME): UDFLAGS+=-version=Shared
$(UT_DRUNTIME): $(OBJS) $(SRCS)
	$(DMD) $(UDFLAGS) -shared -version=druntime_unittest -unittest -of$@ $(SRCS) $(OBJS) -L-ldl -debuglib= -defaultlib=

$(OBJDIR)/test_runner$(DOTEXE): $(UT_DRUNTIME) src/test_runner.d
	$(DMD) $(UDFLAGS) -of$@ src/test_runner.d -L$(UT_DRUNTIME) -debuglib= -defaultlib=

endif

# macro that returns the module name given the src path
moduleName=$(subst rt.invariant,invariant,$(subst object_,object,$(subst /,.,$(1))))

$(OBJDIR)/% : $(OBJDIR)/test_runner$(DOTEXE)
	@$(MKDIR) -p $(dir $@).
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

test/init_fini/.run test/exceptions/.run: $(DRUNTIME)
test/shared/.run: $(DRUNTIMESO)

test/%/.run: test/%/Makefile
	$(QUIET)$(MAKE) -C test/$* MODEL=$(MODEL) OS=$(OS) DMD=$(abspath $(DMD)) \
		DRUNTIME=$(abspath $(DRUNTIME)) DRUNTIMESO=$(abspath $(DRUNTIMESO)) QUIET=$(QUIET)

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
	$(QUIET)$(RUN) $(OBJDIR)/test_runner$(DOTEXE) $(call moduleName,$*)
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

install: target
	mkdir -p $(INSTALL_DIR)/html
	cp -r doc/* $(INSTALL_DIR)/html/
	mkdir -p $(INSTALL_DIR)/import
	cp -r import/* $(INSTALL_DIR)/import/
	mkdir -p $(INSTALL_DIR)/lib
	cp -r lib/* $(INSTALL_DIR)/lib/
	cp LICENSE $(INSTALL_DIR)/druntime-LICENSE.txt

clean: $(addsuffix /.clean,$(ADDITIONAL_TESTS))
	rm -rf obj lib $(IMPDIR) $(DOCDIR) druntime.zip

test/%/.clean: test/%/Makefile
	$(MAKE) -C test/$* clean
