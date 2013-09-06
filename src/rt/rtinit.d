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
        return true;
    }
    catch (Throwable e)
    {
        if (dg)
            dg(e);
        else
            throw e;    // rethrow, don't silently ignore error
        /* Rethrow, and the two STD functions aren't called?
         * This needs rethinking.
         */
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

/*******************************************
 * Loads a DLL written in D with the name 'name'.
 * Returns:
 *      opaque handle to the DLL if successfully loaded
 *      null if failure
 */
version (Windows)
{
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
}
else version (Posix)
{
    extern (C) void* rt_loadLibrary(const char* name)
    {
        throw new Exception("rt_loadLibrary not yet implemented on Posix.");
        version (none)
        {
            /* This also means that the library libdl.so must be linked in,
             * meaning this code should go into a separate module so it is only
             * linked in if rt_loadLibrary() is actually called.
             */
            import core.sys.posix.dlfcn;

            auto dl_handle = dlopen(name, RTLD_LAZY);
            if (!dl_handle)
                return null;

            /* As the DLL is now loaded, if we get here, it means that
             * the DLL has also successfully called all the functions in its .ctors
             * segment. For D, that means all the _d_dso_registry() calls are done.
             * Next up is:
             *  registering the DLL's static data segments with the GC
             *  (Does the DLL's TLS data need to be registered with the GC?)
             *  registering the DLL's exception handler tables
             *  calling the DLL's module constructors
             *  calling the DLL's TLS module constructors
             *  calling the DLL's unit tests
             */
        }
    }
}

/*************************************
 * Unloads DLL that was previously loaded by rt_loadLibrary().
 * Input:
 *      ptr     the handle returned by rt_loadLibrary()
 * Returns:
 *      true    succeeded
 *      false   some failure happened
 */
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
        version (none)
        {
            import core.sys.posix.dlfcn;

            /* Perform the following:
             *  calling the DLL's TLS module destructors
             *  calling the DLL's module destructors
             *  unregistering the DLL's exception handler tables
             *  (Does the DLL's TLS data need to be unregistered with the GC?)
             *  unregistering the DLL's static data segments with the GC
             */

            dlclose(ptr);
            /* dlclose() will also call all the functions in the .dtors segment,
             * meaning calls to _d_dso_register() will get called.
             */
        }
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

bool runModuleUnitTests()
{
    foreach (ref sg; SectionGroup)
		if(!core.runtime.runModuleUnitTests(sg.modules))
			return false;
	return true;
}

