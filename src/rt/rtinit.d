/**
* Contains runtime initialization and support routines.
*
* Copyright: Copyright Digital Mars 2000 - 2012.
* License: Distributed under the
*      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
*    (See accompanying file LICENSE)
* Authors:   Walter Bright, Sean Kelly
* Source: $(DRUNTIMESRC src/rt/_dmain2.d)
*/

module rt.rtinit;

import rt.monitor_;
import rt.critical_;
import rt.memory;
import rt.minfo;
import rt.sections;

import core.runtime;
import core.stdc.stdlib;
import core.thread : thread_joinAll;

extern (C) void gc_init();
extern (C) void gc_term();

version (Windows)
{
    private import core.stdc.wchar_;

    extern (Windows)
    {
        alias int function() FARPROC;
        FARPROC    GetProcAddress(void*, in char*);
        void*      LoadLibraryW(in wchar_t*);
        int        FreeLibrary(void*);
        void*      LocalFree(void*);
        export int MultiByteToWideChar(uint, uint, in char*, int, wchar_t*, int);
    }
}

void _d_criticalInit()
{
    _STI_monitor_staticctor();
    _STI_critical_init();
}

alias void delegate(Throwable) ExceptionHandler;

extern (C) bool rt_init(ExceptionHandler dg = null)
{
    _d_criticalInit();

    try
    {
        initSections();
        gc_init();
        initStaticDataGC();
        rt_moduleCtor();
        rt_moduleTlsCtor();
        runModuleUnitTests();
        return true;
    }
    catch (Throwable e)
    {
        if (dg)
            dg(e);
        else
            throw e;    // rethrow, don't silently ignore error
    }
    _d_criticalTerm();
    return false;
}

void _d_criticalTerm()
{
    _STD_critical_term();
    _STD_monitor_staticdtor();
}

extern (C) bool rt_term(ExceptionHandler dg = null)
{
    try
    {
        rt_moduleTlsDtor();
        thread_joinAll();
        rt_moduleDtor();
        gc_term();
        finiSections();
        return true;
    }
    catch (Throwable e)
    {
        if (dg)
            dg(e);
    }
    finally
    {
        _d_criticalTerm();
    }
    return false;
}

/***********************************
* These are a temporary means of providing a GC hook for DLL use.  They may be
* replaced with some other similar functionality later.
*/
extern (C)
{
    void* gc_getProxy();
    void  gc_setProxy(void* p);
    void  gc_clrProxy();

    alias void* function()      gcGetFn;
    alias void  function(void*) gcSetFn;
    alias void  function()      gcClrFn;
}

extern (C) void* rt_loadLibrary(in char[] name)
{
    version (Windows)
    {
        if (name.length == 0) return null;
        // Load a DLL at runtime
        enum CP_UTF8 = 65001;
        auto len = MultiByteToWideChar(
									   CP_UTF8, 0, name.ptr, cast(int)name.length, null, 0);
        if (len == 0)
            return null;

        auto buf = cast(wchar_t*)malloc((len+1) * wchar_t.sizeof);
        if (buf is null)
            return null;
        scope (exit)
            free(buf);

        len = MultiByteToWideChar(CP_UTF8, 0, name.ptr, cast(int)name.length, buf, len);
        if (len == 0)
            return null;

        buf[len] = '\0';

        // BUG: LoadLibraryW() call calls rt_init(), which fails if proxy is not set!
        auto mod = LoadLibraryW(buf);
        if (mod is null)
            return mod;
        gcSetFn gcSet = cast(gcSetFn) GetProcAddress(mod, "gc_setProxy");
        if (gcSet !is null)
        {   // BUG: Set proxy, but too late
            gcSet(gc_getProxy());
        }
        return mod;

    }
    else version (Posix)
    {
        throw new Exception("rt_loadLibrary not yet implemented on Posix.");
    }
}

extern (C) bool rt_unloadLibrary(void* ptr)
{
    version (Windows)
    {
        gcClrFn gcClr  = cast(gcClrFn) GetProcAddress(ptr, "gc_clrProxy");
        if (gcClr !is null)
            gcClr();
        return FreeLibrary(ptr) != 0;
    }
    else version (Posix)
    {
        throw new Exception("rt_unloadLibrary not yet implemented on Posix.");
    }
}

// NOTE: This is to preserve compatibility with old Windows DLLs.
extern (C) void _moduleCtor()
{
    rt_moduleCtor();
}

extern (C) void _moduleDtor()
{
    rt_moduleDtor();
}

extern (C) void _moduleTlsCtor()
{
    rt_moduleTlsCtor();
}

extern (C) void _moduleTlsDtor()
{
    rt_moduleTlsDtor();
}

// command line arguments
struct CArgs
{
    int argc;
    char** argv;
}

__gshared CArgs _cArgs;

extern (C) CArgs rt_cArgs()
{
    return _cArgs;
}

__gshared string[] _d_args = null;

extern (C) string[] rt_args()
{
    return _d_args;
}

bool runModuleUnitTests()
{
    foreach (ref sg; SectionGroup)
		if(!core.runtime.runModuleUnitTests(sg.modules))
			return false;
	return true;
}

