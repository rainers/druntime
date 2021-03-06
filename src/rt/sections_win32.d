/**
 * Written in the D programming language.
 * This module provides Win32-specific support for sections.
 *
 * Copyright: Copyright Digital Mars 2008 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly, Martin Nowak
 * Source: $(DRUNTIMESRC src/rt/_sections_win32.d)
 */

module rt.sections_win32;

version(CRuntime_DigitalMars):

// debug = PRINTF;
debug(PRINTF) import core.stdc.stdio;
import rt.minfo;

struct SectionGroup
{
    static int opApply(scope int delegate(ref SectionGroup) dg)
    {
        return dg(_sections);
    }

    static int opApplyReverse(scope int delegate(ref SectionGroup) dg)
    {
        return dg(_sections);
    }

    @property inout(ModuleInfo*)[] modules() inout
    {
        return _moduleGroup.modules;
    }

    @property ref inout(ModuleGroup) moduleGroup() inout
    {
        return _moduleGroup;
    }

    @property inout(void[])[] gcRanges() inout
    {
        return _gcRanges[];
    }

    @property inout(void[])[] gcRanges_hp() inout
    {
        return _gcRanges_hp[];
    }

    @property inout(void[])[] gcRanges_hptls() inout
    {
        return _gcRanges_hptls[];
    }

private:
    ModuleGroup _moduleGroup;
    void[][1] _gcRanges;
    void[][1] _gcRanges_hp;
    void[][1] _gcRanges_hptls;
}

// from minit.asm
extern(C) void[] _hparea();
extern(C) void[] _tlshparea();

// version = conservative_roots;

void initSections()
{
    _sections._moduleGroup = ModuleGroup(getModuleInfos());

    version(conservative_roots)
    {
        auto pbeg = cast(void*)&_xi_a;
        auto pend = cast(void*)&_end;
        _sections._gcRanges[0] = pbeg[0 .. pend - pbeg];
    }
    else
    {
        _sections._gcRanges_hp[0] = _hparea();
        _sections._gcRanges_hptls[0] = _tlshparea();
    }
}

void finiSections()
{
}

void[] initTLSRanges()
{
    auto pbeg = cast(void*)&_tlsstart;
    auto pend = cast(void*)&_tlsend;
    return pbeg[0 .. pend - pbeg];
}

void finiTLSRanges(void[] rng)
{
}

void scanTLSRanges(void[] rng, scope void delegate(void* pbeg, void* pend) dg)
{
    dg(rng.ptr, rng.ptr + rng.length);
}

private:

__gshared SectionGroup _sections;

// Windows: this gets initialized by minit.asm
extern(C) __gshared ModuleInfo*[] _moduleinfo_array;
extern(C) void _minit();

ModuleInfo*[] getModuleInfos()
out (result)
{
    foreach(m; result)
        assert(m !is null);
}
body
{
    // _minit directly alters the global _moduleinfo_array
    _minit();
    return _moduleinfo_array;
}

extern(C)
{
    extern __gshared
    {
        int _xi_a;      // &_xi_a just happens to be start of data segment
        //int _edata;   // &_edata is start of BSS segment
        int _end;       // &_end is past end of BSS
    }

    extern
    {
        int _tlsstart;
        int _tlsend;
    }
}
