/**
 * Runtime support for dynamic libraries.
 *
 * Copyright: Copyright Martin Nowak 2012-2013.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Martin Nowak
 * Source: $(DRUNTIMESRC src/rt/_dso.d)
 */
module rt.dso;

version (Windows)
{
    // missing integration with the existing DLL mechanism
    enum USE_DSO = false;
}
else version (linux)
{
    enum USE_DSO = true;
    import core.sys.linux.elf;
    import core.sys.linux.link;
}
else version (OSX)
{
    // missing integration with rt.memory_osx.onAddImage
    enum USE_DSO = false;
}
else version (FreeBSD)
{
    // missing elf and link headers
    enum USE_DSO = false;
}
else
{
    static assert(0, "Unsupported platform");
}

static if (USE_DSO) // '{}' instead of ':' => Bugzilla 8898
{

import rt.minfo;
import rt.deh2;
import rt.util.container;
import core.stdc.stdlib;

struct DSO
{
    static int opApply(scope int delegate(ref DSO) dg)
    {
        foreach(dso; _static_dsos)
        {
            if (auto res = dg(*dso))
                return res;
        }
        return 0;
    }

    static int opApplyReverse(scope int delegate(ref DSO) dg)
    {
        foreach_reverse(dso; _static_dsos)
        {
            if (auto res = dg(*dso))
                return res;
        }
        return 0;
    }

    @property inout(ModuleInfo*)[] modules() inout
    {
        return _moduleGroup.modules;
    }

    @property ref inout(ModuleGroup) moduleGroup() inout
    {
        return _moduleGroup;
    }

    @property inout(FuncTable)[] ehtables() inout
    {
        return _ehtables[];
    }

    @property inout(void[])[] gcRanges() inout
    {
        return _gcRanges[];
    }

    @property void[] tlsRange() const
    {
        return getTLSRange(_tlsMod, _tlsSize);
    }

private:

    invariant()
    {
        assert(_moduleGroup.modules.length);
        assert(_tlsMod || !_tlsSize);
    }

    FuncTable[]     _ehtables;
    ModuleGroup  _moduleGroup;
    Array!(void[]) _gcRanges;
    size_t _tlsMod;
    size_t _tlsSize;
}

private:
/*
 * Static DSOs loaded by the runtime linker. This includes the
 * executable. These can't be unloaded.
 */
__gshared Array!(DSO*) _static_dsos;


///////////////////////////////////////////////////////////////////////////////
// Compiler to runtime interface.
///////////////////////////////////////////////////////////////////////////////


/*
 *
 */
struct CompilerDSOData
{
    size_t _version;
    void** _slot; // can be used to store runtime data
    object.ModuleInfo** _minfo_beg, _minfo_end;
    rt.deh2.FuncTable* _deh_beg, _deh_end;
}

T[] toRange(T)(T* beg, T* end) { return beg[0 .. end - beg]; }

package // dmain weak linkage
extern(C) void _d_dso_registry(CompilerDSOData* data)
{
    // only one supported currently
    data._version >= 1 || assert(0, "corrupt DSO data version");

    // no backlink => register
    if (*data._slot is null)
    {
        DSO* pdso = cast(DSO*).calloc(1, DSO.sizeof);
        assert(typeid(DSO).init().ptr is null);
        *data._slot = pdso; // store backlink in library record

        pdso._moduleGroup = ModuleGroup(toRange(data._minfo_beg, data._minfo_end));
        pdso._ehtables = toRange(data._deh_beg, data._deh_end);

        dl_phdr_info info = void;
        findDSOInfoForAddr(data._slot, &info) || assert(0);

        scanSegments(info, pdso);

        _static_dsos.insertBack(pdso);
    }
    // has backlink => unregister
    else
    {
        DSO* pdso = cast(DSO*)*data._slot;
        assert(pdso == _static_dsos.back); // DSOs are unloaded in reverse order
        _static_dsos.popBack();

        *data._slot = null;
        .free(pdso);
    }
}

///////////////////////////////////////////////////////////////////////////////
// Elf program header iteration
///////////////////////////////////////////////////////////////////////////////


void scanSegments(in ref dl_phdr_info info, DSO* pdso)
{
    foreach (ref phdr; info.dlpi_phdr[0 .. info.dlpi_phnum])
    {
        if (phdr.p_type == PT_LOAD && phdr.p_flags & PF_W)
        {
            auto beg = cast(void*)(info.dlpi_addr + phdr.p_vaddr);
            pdso._gcRanges.insertBack(beg[0 .. phdr.p_memsz]);
        }
        else if (phdr.p_type == PT_TLS)
        {
            assert(!pdso._tlsSize); // is unique per DSO
            pdso._tlsMod = info.dlpi_tls_modid;
            pdso._tlsSize = phdr.p_memsz;
        }
    }
}

nothrow
bool findDSOInfoForAddr(in void* addr, dl_phdr_info* result=null)
{
    static struct DG { const(void)* addr; dl_phdr_info* result; }

    extern(C) nothrow
    int callback(dl_phdr_info* info, size_t sz, void* arg)
    {
        auto p = cast(DG*)arg;
        if (findSegmentForAddr(*info, p.addr))
        {
            if (p.result !is null) *p.result = *info;
            return 1; // break;
        }
        return 0; // continue iteration
    }

    auto dg = DG(addr, result);
    return dl_iterate_phdr(&callback, &dg) != 0;
}

nothrow
bool findSegmentForAddr(in ref dl_phdr_info info, in void* addr, ElfW!"Phdr"* result=null)
{
    if (addr < cast(void*)info.dlpi_addr) // quick reject
        return false;

    foreach (ref phdr; info.dlpi_phdr[0 .. info.dlpi_phnum])
    {
        auto beg = cast(void*)(info.dlpi_addr + phdr.p_vaddr);
        if (cast(size_t)(addr - beg) < phdr.p_memsz)
        {
            if (result !is null) *result = phdr;
            return true;
        }
    }
    return false;
}

///////////////////////////////////////////////////////////////////////////////
// TLS module helper
///////////////////////////////////////////////////////////////////////////////


/*
 * Returns: the TLS memory range for a given module and the calling
 * thread or null if that module has no TLS.
 *
 * Note: This will cause the TLS memory to be eagerly allocated.
 */
struct tls_index
{
    size_t ti_module;
    size_t ti_offset;
}

extern(C) void* __tls_get_addr(tls_index* ti);

void[] getTLSRange(size_t mod, size_t sz)
{
    if (mod == 0)
        return null;

    // base offset
    auto ti = tls_index(mod, 0);
    return __tls_get_addr(&ti)[0 .. sz];
}

}
