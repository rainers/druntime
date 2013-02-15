/**
 * Contains main program support routines.
 *
 * Copyright: Copyright Digital Mars 2000 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly
 * Source: $(DRUNTIMESRC src/rt/_dmain2.d)
 */

module rt.dmain3;

private
{
    import rt.minfo;
    import rt.memory;
    import rt.util.console;
    import rt.util.string;
    import core.stdc.stddef;
    import core.stdc.stdlib;
    import core.stdc.string;
    import core.stdc.stdio;   // for printf()
}

version (Windows)
{
    extern (Windows)
    {
        alias int function() FARPROC;
        FARPROC    GetProcAddress(void*, in char*);
        void*      LoadLibraryW(in wchar_t*);
        int        FreeLibrary(void*);
        export int MultiByteToWideChar(uint, uint, in char*, int, wchar_t*, int);
    }
}

version (all)
{
    extern (C) Throwable.TraceInfo _d_traceContext(void* ptr = null);

    extern (C) void _d_createTrace(Object *o)
    {
        auto t = cast(Throwable) o;

        if (t !is null && t.info is null &&
            cast(byte*) t !is t.classinfo.init.ptr)
        {
            t.info = _d_traceContext();
        }
    }
}

version (FreeBSD)
{
    import core.stdc.fenv;
}

extern (C) void _STI_monitor_staticctor();
extern (C) void _STD_monitor_staticdtor();
extern (C) void _STI_critical_init();
extern (C) void _STD_critical_term();
extern (C) void gc_init();
extern (C) void gc_term();
//extern (C) void rt_moduleCtor();
//extern (C) void rt_moduleTlsCtor();
//extern (C) void rt_moduleDtor();
//extern (C) void rt_moduleTlsDtor();
extern (C) void thread_joinAll();

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

version (OSX)
{
    // The bottom of the stack
    extern (C) __gshared void* __osx_stack_end = cast(void*)0xC0000000;

    extern (C) extern (C) void _d_osx_image_init2();
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

        len = MultiByteToWideChar(
            CP_UTF8, 0, name.ptr, cast(int)name.length, buf, len);
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

/***********************************
 * These functions must be defined for any D program linked
 * against this library.
 */
extern (C) void onAssertError(string file, size_t line);
extern (C) void onAssertErrorMsg(string file, size_t line, string msg);
extern (C) void onUnittestErrorMsg(string file, size_t line, string msg);
extern (C) void onRangeError(string file, size_t line);
extern (C) void onHiddenFuncError(Object o);
extern (C) void onSwitchError(string file, size_t line);
extern (C) bool runModuleUnitTests(ModuleInfo*[]  _modules);

// this function is called from the utf module
//extern (C) void onUnicodeError(string msg, size_t idx);

/***********************************
 * These are internal callbacks for various language errors.
 */

extern (C)
{
    // Use ModuleInfo to get file name for "m" versions

    void _d_assertm(ModuleInfo* m, uint line)
    {
        onAssertError(m.name, line);
    }

    void _d_assert_msg(string msg, string file, uint line)
    {
        onAssertErrorMsg(file, line, msg);
    }

    void _d_assert(string file, uint line)
    {
        onAssertError(file, line);
    }

    void _d_unittestm(ModuleInfo* m, uint line)
    {
        _d_unittest(m.name, line);
    }

    void _d_unittest_msg(string msg, string file, uint line)
    {
        onUnittestErrorMsg(file, line, msg);
    }

    void _d_unittest(string file, uint line)
    {
        _d_unittest_msg("unittest failure", file, line);
    }

    void _d_array_bounds(ModuleInfo* m, uint line)
    {
        onRangeError(m.name, line);
    }

    void _d_switch_error(ModuleInfo* m, uint line)
    {
        onSwitchError(m.name, line);
    }
}

extern (C) void _d_hidden_func()
{
    Object o;
    version(D_InlineAsm_X86)
        asm
        {
            mov o, EAX;
        }
    else version(D_InlineAsm_X86_64)
        asm
        {
            mov o, RDI;
        }
    else
        static assert(0, "unknown os");

    onHiddenFuncError(o);
}

__gshared string[] _d_args = null;

extern (C) string[] rt_args()
{
    return _d_args;
}

// This variable is only ever set by a debugger on initialization so it should
// be fine to leave it as __gshared.
extern (C) __gshared bool rt_trapExceptions = true;

void _d_criticalInit()
{
  _STI_monitor_staticctor();
  _STI_critical_init();
}

alias void delegate(Throwable) ExceptionHandler;

extern (C) bool rt_init(ExceptionHandler dg = null)
{
    version (OSX)
        _d_osx_image_init2();
    _d_criticalInit();

    try
    {
        gc_init();
        initStaticDataGC();
        rt_moduleCtor();
        rt_moduleTlsCtor();
        runModuleUnitTests(getModuleInfos());
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
