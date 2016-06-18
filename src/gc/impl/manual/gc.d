/**
 * This module contains a minimal garbage collector implementation according to
 * published requirements.  This library is mostly intended to serve as an
 * example, but it is usable in applications which do not rely on a garbage
 * collector to clean up memory (ie. when dynamic array resizing is not used,
 * and all memory allocated with 'new' is freed deterministically with
 * 'delete').
 *
 * Please note that block attribute data must be tracked, or at a minimum, the
 * FINALIZE bit must be tracked for any allocated memory block because calling
 * rt_finalize on a non-object block can result in an access violation.  In the
 * allocator below, this tracking is done via a leading uint bitmask.  A real
 * allocator may do better to store this data separately, similar to the basic
 * GC.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sean Kelly
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module gc.impl.manual.gc;

import gc.config;
import gc.stats;

//import gc.proxy;
import gc.gc;

import cstdlib = core.stdc.stdlib : calloc, free, malloc, realloc;

static import core.memory;

private
{
    alias BlkAttr = core.memory.GC.BlkAttr;
    alias BlkInfo = core.memory.GC.BlkInfo;
    alias RootIterator = int delegate(scope int delegate(ref Root) nothrow dg);
    alias RangeIterator = int delegate(scope int delegate(ref Range) nothrow dg);
}

extern (C) void onOutOfMemoryError(void* pretend_sideffect = null) @trusted pure nothrow @nogc; /* dmd @@@BUG11461@@@ */

__gshared ManualGC instance;

class ManualGC : GC
{
    __gshared Root* roots = null;
    __gshared size_t nroots = 0;

    __gshared Range* ranges = null;
    __gshared size_t nranges = 0;

    static void initialize()
    {
        import core.stdc.string;

        if (config.gc != "manual")
            return;

        auto p = cstdlib.malloc(__traits(classInstanceSize, ManualGC));
        if (!p)
            onOutOfMemoryError();

        instance = cast(ManualGC) memcpy(p, typeid(ManualGC).initializer.ptr,
            typeid(ManualGC).initializer.length);

        instance.__ctor();

        gc_setGC(instance);
    }

    this()
    {
    }

    void Dtor()
    {
        cstdlib.free(roots);
        cstdlib.free(ranges);
        cstdlib.free(cast(void*) instance);
    }

    void enable()
    {
    }

    void disable()
    {
    }

    void collect() nothrow
    {
    }

    void minimize() nothrow
    {
    }

    uint getAttr(void* p) nothrow
    {
        return 0;
    }

    uint setAttr(void* p, uint mask) nothrow
    {
        return 0;
    }

    uint clrAttr(void* p, uint mask) nothrow
    {
        return 0;
    }

    void* malloc(size_t size, uint bits, const TypeInfo ti) nothrow
    {
        void* p = cstdlib.malloc(size);

        if (size && p is null)
            onOutOfMemoryError();
        return p;
    }

    BlkInfo qalloc(size_t size, uint bits, const TypeInfo ti) nothrow
    {
        BlkInfo retval;
        retval.base = malloc(size, bits, ti);
        retval.size = size;
        retval.attr = bits;
        return retval;
    }

    void* calloc(size_t size, uint bits, const TypeInfo ti) nothrow
    {
        void* p = cstdlib.calloc(1, size);

        if (size && p is null)
            onOutOfMemoryError();
        return p;
    }

    void* realloc(void* p, size_t size, uint bits, const TypeInfo ti) nothrow
    {
        p = cstdlib.realloc(p, size);

        if (size && p is null)
            onOutOfMemoryError();
        return p;
    }

    size_t extend(void* p, size_t minsize, size_t maxsize, const TypeInfo ti) nothrow
    {
        return 0;
    }

    size_t reserve(size_t size) nothrow
    {
        return 0;
    }

    void free(void* p) nothrow
    {
        cstdlib.free(p);
    }

    /**
     * Determine the base address of the block containing p.  If p is not a gc
     * allocated pointer, return null.
     */
    void* addrOf(void* p) nothrow
    {
        return null;
    }

    /**
     * Determine the allocated size of pointer p.  If p is an interior pointer
     * or not a gc allocated pointer, return 0.
     */
    size_t sizeOf(void* p) nothrow
    {
        return 0;
    }

    /**
     * Determine the base address of the block containing p.  If p is not a gc
     * allocated pointer, return null.
     */
    BlkInfo query(void* p) nothrow
    {
        return BlkInfo.init;
    }

    GCStats stats() nothrow
    {
        return GCStats.init;
    }

    void addRoot(void* p) nothrow
    {
        Root* r = cast(Root*) cstdlib.realloc(roots, (nroots + 1) * roots[0].sizeof);
        if (r is null)
            onOutOfMemoryError();
        r[nroots++] = p;
        roots = r;
    }

    void removeRoot(void* p) nothrow
    {
        for (size_t i = 0; i < nroots; ++i)
        {
            if (roots[i] is p)
            {
                roots[i] = roots[--nroots];
                return;
            }
        }
        assert(false);
    }

    @property RootIterator rootIter() @nogc
    {
        return &rootsApply;
    }

    private int rootsApply(scope int delegate(ref Root) nothrow dg)
    {
        int result = 0;
        for (int i = 0; i < nroots; i++)
        {
            result = dg(roots[i]);

            if (result)
                break;
        }

        return result;
    }

    void addRange(void* p, size_t sz, const TypeInfo ti = null) nothrow
    {
        Range* r = cast(Range*) cstdlib.realloc(ranges, (nranges + 1) * ranges[0].sizeof);
        if (r is null)
            onOutOfMemoryError();
        r[nranges].pbot = p;
        r[nranges].ptop = p + sz;
        r[nranges].ti = cast() ti;
        ranges = r;
        ++nranges;
    }

    void removeRange(void* p) nothrow
    {
        for (size_t i = 0; i < nranges; ++i)
        {
            if (ranges[i].pbot is p)
            {
                ranges[i] = ranges[--nranges];
                return;
            }
        }
        assert(false);
    }

    @property int delegate(scope int delegate(ref Range) nothrow dg) rangeIter() @nogc
    {
        return &rangesApply;
    }

    private int rangesApply(scope int delegate(ref Range) nothrow dg)
    {
        int result = 0;
        for (int i = 0; i < nranges; i++)
        {
            result = dg(ranges[i]);

            if (result)
                break;
        }

        return result;
    }

    void runFinalizers(in void[] segment) nothrow
    {
    }

    bool inFinalizer() nothrow
    {
        return false;
    }
}