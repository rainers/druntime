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
import core.stdc.stdio;   // for printf()
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
        void*      LoadLibraryA(in char*);
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

/**
 * Keep track of how often rt_init/rt_term were called.
 */
shared size_t _initCount;

/**********************************************
 * Initialize druntime.
 * If a C program wishes to call D code, and there's no D main(), then it
 * must call rt_init() and rt_term().
 */
extern (C) int rt_init()
{
    /* @@BUG 11380 @@ Need to synchronize rt_init/rt_term calls for
       version (Shared) druntime, because multiple C threads might
       initialize different D libraries without knowing about the
       shared druntime. Also we need to attach any thread that calls
       rt_init. */
    if (_initCount++) return 1;

    _d_criticalInit();

    try
    {
        initSections();
        gc_init();
        initStaticDataGC();
        rt_moduleCtor();
        rt_moduleTlsCtor();
        return 1;
    }
    catch (Throwable t)
    {
        _initCount = 0;
        printThrowable(t);
    }
    _d_criticalTerm();
    return 0;
}

void _d_criticalTerm()
{
    _STD_critical_term();
    _STD_monitor_staticdtor();
}

/**********************************************
 * Terminate use of druntime.
 */
extern (C) int rt_term()
{
    if (!_initCount) return 0; // was never initialized
    if (--_initCount) return 1;

    try
    {
        rt_moduleTlsDtor();
        thread_joinAll();
        rt_moduleDtor();
        gc_term();
        finiSections();
        return 1;
    }
    catch (Throwable t)
    {
        printThrowable(t);
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

version (Windows)
{
    /*******************************************
     * Loads a DLL written in D with the name 'name'.
     * Returns:
     *      opaque handle to the DLL if successfully loaded
     *      null if failure
     */
    extern (C) void* rt_loadLibrary(const char* name)
    {
        return initLibrary(.LoadLibraryA(name));
    }

    extern (C) void* rt_loadLibraryW(const wchar_t* name)
    {
        return initLibrary(.LoadLibraryW(name));
    }

    void* initLibrary(void* mod)
    {
        // BUG: LoadLibrary() call calls rt_init(), which fails if proxy is not set!
        // (What? LoadLibrary() is a Windows API call, it shouldn't call rt_init().)
        if (mod is null)
            return mod;
        gcSetFn gcSet = cast(gcSetFn) GetProcAddress(mod, "gc_setProxy");
        if (gcSet !is null)
        {   // BUG: Set proxy, but too late
            gcSet(gc_getProxy());
        }
        return mod;
    }

    /*************************************
     * Unloads DLL that was previously loaded by rt_loadLibrary().
     * Input:
     *      ptr     the handle returned by rt_loadLibrary()
     * Returns:
     *      1   succeeded
     *      0   some failure happened
     */
    extern (C) int rt_unloadLibrary(void* ptr)
    {
        gcClrFn gcClr  = cast(gcClrFn) GetProcAddress(ptr, "gc_clrProxy");
        if (gcClr !is null)
            gcClr();
        return FreeLibrary(ptr) != 0;
    }
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

private void printThrowable(Throwable t)
{
    void sink(const(char)[] buf) nothrow
    {
        fprintf(stderr, "%.*s", cast(int)buf.length, buf.ptr);
    }

    for (; t; t = t.next)
    {
        t.toString(&sink); sink("\n");

        auto e = cast(Error)t;
        if (e is null || e.bypassedException is null) continue;

        sink("=== Bypassed ===\n");
        for (auto t2 = e.bypassedException; t2; t2 = t2.next)
        {
            t2.toString(&sink); sink("\n");
        }
        sink("=== ~Bypassed ===\n");
    }
}
bool runModuleUnitTests()
{
    foreach (ref sg; SectionGroup)
		if(!core.runtime.runModuleUnitTests(sg.modules))
			return false;
	return true;
}

