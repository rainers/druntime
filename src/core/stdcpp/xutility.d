/**
 * D header file for interaction with Microsoft C++ <xutility>
 *
 * Copyright: Copyright (c) 2018 D Language Foundation
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Manu Evans
 * Source:    $(DRUNTIMESRC core/stdcpp/xutility.d)
 */

module core.stdcpp.xutility;

extern(C++, "std"):

version(CRuntime_Microsoft)
{
    import core.stdcpp.type_traits : is_empty;

    // By specific user request
    version (_ITERATOR_DEBUG_LEVEL_0)
        enum _ITERATOR_DEBUG_LEVEL = 0;
    else version (_ITERATOR_DEBUG_LEVEL_1)
        enum _ITERATOR_DEBUG_LEVEL = 1;
    else version (_ITERATOR_DEBUG_LEVEL_2)
        enum _ITERATOR_DEBUG_LEVEL = 2;
    else
    {
        // Match the C Runtime
        static if (__CXXLIB__ == "libcmtd" || __CXXLIB__ == "msvcrtd")
            enum _ITERATOR_DEBUG_LEVEL = 2;
        else static if (__CXXLIB__ == "libcmt" || __CXXLIB__ == "msvcrt")
            enum _ITERATOR_DEBUG_LEVEL = 0;
        else
        {
            static if (__CXXLIB__.length > 0)
                pragma(msg, "Unrecognised C++ runtime library '" ~ __CXXLIB__ ~ "'");

            // No runtime specified; as a best-guess, -release will produce code that matches the MSVC release CRT
            debug
                enum _ITERATOR_DEBUG_LEVEL = 2;
            else
                enum _ITERATOR_DEBUG_LEVEL = 0;
        }
    }

package:
    struct _Container_base0 {}

    struct _Iterator_base12
    {
        _Container_proxy *_Myproxy;
        _Iterator_base12 *_Mynextiter;
    }
    struct _Container_proxy
    {
        const(_Container_base12)* _Mycont;
        _Iterator_base12* _Myfirstiter;
    }
    struct _Container_base12 { _Container_proxy* _Myproxy; }

    static if (_ITERATOR_DEBUG_LEVEL == 0)
        alias _Container_base = _Container_base0;
    else
        alias _Container_base = _Container_base12;

    extern (C++, class) struct _Compressed_pair(_Ty1, _Ty2, bool Ty1Empty = is_empty!_Ty1.value)
    {
        enum _HasFirst = !Ty1Empty;

        ref inout(_Ty1) _Get_first() inout nothrow @safe @nogc { return _Myval1; }
        ref inout(_Ty2) _Get_second() inout nothrow @safe @nogc { return _Myval2; }

        static if (!Ty1Empty)
            _Ty1 _Myval1;
        else
        {
            @property ref inout(_Ty1) _Myval1() inout nothrow @trusted @nogc { return *_GetBase(); }
            private inout(_Ty1)* _GetBase() inout { return cast(_Ty1*)&this; }
        }
        _Ty2 _Myval2;
    }

    // these are all [[noreturn]]
    void _Xbad() nothrow @trusted @nogc;
    void _Xinvalid_argument(const(char)* message) nothrow @trusted @nogc;
    void _Xlength_error(const(char)* message) nothrow @trusted @nogc;
    void _Xout_of_range(const(char)* message) nothrow @trusted @nogc;
    void _Xoverflow_error(const(char)* message) nothrow @trusted @nogc;
    void _Xruntime_error(const(char)* message) nothrow @trusted @nogc;
}
