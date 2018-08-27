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
package:
    // these are all [[noreturn]]
    void _Xbad() nothrow @trusted @nogc;
    void _Xinvalid_argument(const(char)* message) nothrow @trusted @nogc;
    void _Xlength_error(const(char)* message) nothrow @trusted @nogc;
    void _Xout_of_range(const(char)* message) nothrow @trusted @nogc;
    void _Xoverflow_error(const(char)* message) nothrow @trusted @nogc;
    void _Xruntime_error(const(char)* message) nothrow @trusted @nogc;
}
