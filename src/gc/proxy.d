module gc.gc;

import gc.impl.conservative.gc;
import gc.impl.manual.gc;
import gc.config;
import gc.stats;


private
{
    static import core.memory;
    alias BlkInfo = core.memory.GC.BlkInfo;

    extern (C) void thread_init();
    extern (C) void thread_term();

    __gshared GC instance;
    __gshared GC ithis;

    alias RootIterator = int delegate(scope int delegate(ref Root) nothrow dg);
    alias RangeIterator = int delegate(scope int delegate(ref Range) nothrow dg);
}


struct Root
{
    void* proot;
    alias proot this;
}

struct Range
{
    void *pbot;
    void *ptop;
    TypeInfo ti; // should be tail const, but doesn't exist for references
    alias pbot this; // only consider pbot for relative ordering (opCmp)
}


const uint GCVERSION = 1;       // increment every time we change interface
                                // to GC.

interface GC
{

    /*
     *
     */
    void Dtor();

    /**
     *
     */
    void enable();


    /**
     *
     */
    void disable();


    /**
     *
     */
    void collect() nothrow;


    /**
     * minimize free space usage
     */
    void minimize() nothrow;


    /**
     *
     */
    uint getAttr(void* p) nothrow;


    /**
     *
     */
    uint setAttr(void* p, uint mask) nothrow;


    /**
     *
     */
    uint clrAttr(void* p, uint mask) nothrow;


    /**
     *
     */
    void *malloc(size_t size, uint bits, const TypeInfo ti) nothrow;


    /*
     *
     */
    BlkInfo qalloc( size_t size, uint bits, const TypeInfo ti) nothrow;


    /*
     *
     */
    void *calloc(size_t size, uint bits, const TypeInfo ti) nothrow;


    /*
     *
     */
    void *realloc(void *p, size_t size, uint bits, const TypeInfo ti) nothrow;


    /**
     * Attempt to in-place enlarge the memory block pointed to by p by at least
     * minsize bytes, up to a maximum of maxsize additional bytes.
     * This does not attempt to move the memory block (like realloc() does).
     *
     * Returns:
     *  0 if could not extend p,
     *  total size of entire memory block if successful.
     */
    size_t extend(void* p, size_t minsize, size_t maxsize, const TypeInfo ti) nothrow;


    /**
     *
     */
    size_t reserve(size_t size) nothrow;


    /**
     *
     */
    void free(void *p) nothrow;


    /**
     * Determine the base address of the block containing p.  If p is not a gc
     * allocated pointer, return null.
     */
    void* addrOf(void *p) nothrow;


    /**
     * Determine the allocated size of pointer p.  If p is an interior pointer
     * or not a gc allocated pointer, return 0.
     */
    size_t sizeOf(void *p) nothrow;


    /**
     * Determine the base address of the block containing p.  If p is not a gc
     * allocated pointer, return null.
     */
    BlkInfo query(void *p) nothrow;


    /**
     * Retrieve statistics about garbage collection.
     * Useful for debugging and tuning.
     */
    GCStats stats() nothrow;


    /**
     * add p to list of roots
     */
    void addRoot(void *p) nothrow @nogc;


    /**
     * remove p from list of roots
     */
    void removeRoot(void *p) nothrow @nogc;


    /**
     *
     */
    @property RootIterator rootIter() @nogc;


    /**
     * add range to scan for roots
     */
    void addRange(void *p, size_t sz, const TypeInfo ti) nothrow @nogc;


    /**
     * remove range
     */
    void removeRange(void *p) nothrow @nogc;


    /**
     *
     */
    @property RangeIterator rangeIter() @nogc;


    /**
     * run finalizers
     */
    void runFinalizers(in void[] segment) nothrow;

    /*
     *
     */
    bool inFinalizer() nothrow;
}


extern (C)
{

    void gc_init()
    {
        config.initialize();
        ManualGC.initialize();
        ConservativeGC.initialize();

        // NOTE: The GC must initialize the thread library
        //       before its first collection.
        thread_init();
    }

    void gc_term()
    {
        // NOTE: There may be daemons threads still running when this routine is
        //       called.  If so, cleaning memory out from under then is a good
        //       way to make them crash horribly.  This probably doesn't matter
        //       much since the app is supposed to be shutting down anyway, but
        //       I'm disabling cleanup for now until I can think about it some
        //       more.
        //
        // NOTE: Due to popular demand, this has been re-enabled.  It still has
        //       the problems mentioned above though, so I guess we'll see.

        instance.collect();

        if(ithis !is instance)
        {
            instance.Dtor();
        }
        ithis.Dtor();

        thread_term();
    }

    void gc_enable()
    {
        instance.enable();
    }

    void gc_disable()
    {
        instance.disable();
    }

    void gc_collect() nothrow
    {
        instance.collect();
    }

    void gc_minimize() nothrow
    {
        instance.minimize();
    }

    uint gc_getAttr( void* p ) nothrow
    {
        return instance.getAttr(p);
    }

    uint gc_setAttr( void* p, uint a ) nothrow
    {
        return instance.setAttr(p, a);
    }

    uint gc_clrAttr( void* p, uint a ) nothrow
    {
        return instance.clrAttr(p, a);
    }

    void* gc_malloc( size_t sz, uint ba = 0, const TypeInfo ti = null ) nothrow
    {
        return instance.malloc(sz, ba, ti);
    }

    BlkInfo gc_qalloc( size_t sz, uint ba = 0, const TypeInfo ti = null ) nothrow
    {
        return instance.qalloc( sz, ba, ti );
    }

    void* gc_calloc( size_t sz, uint ba = 0, const TypeInfo ti = null ) nothrow
    {
        return instance.calloc( sz, ba, ti );
    }

    void* gc_realloc( void* p, size_t sz, uint ba = 0, const TypeInfo ti = null ) nothrow
    {
        return instance.realloc( p, sz, ba, ti );
    }

    size_t gc_extend( void* p, size_t mx, size_t sz, const TypeInfo ti = null ) nothrow
    {
        return instance.extend( p, mx, sz,ti );
    }

    size_t gc_reserve( size_t sz ) nothrow
    {
        return instance.reserve( sz );
    }

    void gc_free( void* p ) nothrow
    {
        return instance.free( p );
    }

    void* gc_addrOf( void* p ) nothrow
    {
        return instance.addrOf( p );
    }

    size_t gc_sizeOf( void* p ) nothrow
    {
        return instance.sizeOf( p );
    }

    BlkInfo gc_query( void* p ) nothrow
    {
        return instance.query( p );
    }

    // NOTE: This routine is experimental. The stats or function name may change
    //       before it is made officially available.
    GCStats gc_stats() nothrow
    {
        return instance.stats();
    }

    void gc_addRoot( void* p ) nothrow
    {
        return instance.addRoot( p );
    }

    void gc_removeRoot( void* p ) nothrow
    {
        return instance.removeRoot( p );
    }

    void gc_addRange( void* p, size_t sz, const TypeInfo ti = null ) nothrow
    {
        return instance.addRange( p, sz, ti );
    }

    void gc_removeRange( void* p ) nothrow
    {
        return instance.removeRange( p );
    }

    void gc_runFinalizers( in void[] segment ) nothrow
    {
        return instance.runFinalizers( segment );
    }

    bool gc_inFinalizer() nothrow
    {
        return instance.inFinalizer();
    }

    GC gc_getGC() nothrow
    {
        return instance;
    }

    export
    {
        void gc_setGC( GC inst )
        {
            //first time set up
            if(instance is null)
            {
                instance = ithis = inst;
                return;
            }

            foreach(root; inst.rootIter)
            {
                inst.addRoot(root);
            }

            foreach(range; inst.rangeIter)
            {
                inst.addRange(range.pbot, range.ptop - range.pbot, range.ti);
            }

            instance = inst;
        }

        void gc_clrGC()
        {
            foreach(root; ithis.rootIter)
            {
                instance.removeRoot(root);
            }

            foreach(range; ithis.rangeIter)
            {
                instance.removeRange(range);
            }

            instance = ithis;
        }
    }
}