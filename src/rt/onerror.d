/**
* Contains error support routines referenced by the compiler.
*
* Copyright: Copyright Digital Mars 2000 - 2012.
* License: Distributed under the
*      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
*    (See accompanying file LICENSE)
* Authors:   Walter Bright, Sean Kelly
* Source: $(DRUNTIMESRC src/rt/_dmain2.d)
*/

module rt.onerror;

version (all)
{
    extern (C) Throwable.TraceInfo _d_traceContext(void* ptr = null);

    extern (C) void _d_createTrace(Object *o, void* context)
    {
        auto t = cast(Throwable) o;

        if (t !is null && t.info is null &&
            cast(byte*) t !is t.classinfo.init.ptr)
        {
            t.info = _d_traceContext(context);
        }
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

