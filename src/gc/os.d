/**
 * Contains OS-level routines needed by the garbage collector.
 *
 * Copyright: Copyright Digital Mars 2005 - 2013.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, David Friedman, Sean Kelly, Leandro Lucarella
 */

/*          Copyright Digital Mars 2005 - 2013.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module gc.os;


version (Windows)
{
    import core.sys.windows.windows;

    alias int pthread_t;

    pthread_t pthread_self() nothrow
    {
        return cast(pthread_t) GetCurrentThreadId();
    }

    //version = GC_Use_Alloc_Win32;
}
else version (Posix)
{
    import core.sys.posix.sys.mman;
    version (linux) import core.sys.linux.sys.mman : MAP_ANON;
    import core.stdc.stdlib;

    //version = GC_Use_Alloc_MMap;
}
else
{
    import core.stdc.stdlib;

    //version = GC_Use_Alloc_Malloc;
}

/+
static if(is(typeof(VirtualAlloc)))
    version = GC_Use_Alloc_Win32;
else static if (is(typeof(mmap)))
    version = GC_Use_Alloc_MMap;
else static if (is(typeof(valloc)))
    version = GC_Use_Alloc_Valloc;
else static if (is(typeof(malloc)))
    version = GC_Use_Alloc_Malloc;
else static assert(false, "No supported allocation methods available.");
+/

static if (is(typeof(VirtualAlloc))) // version (GC_Use_Alloc_Win32)
{
    enum hasMemWriteWatch = true;

    enum MEM_WRITE_WATCH = 0x00200000;

    /**
     * Map memory.
     */
    void *os_mem_map(size_t nbytes) nothrow
    {
        return VirtualAlloc(null, nbytes, MEM_RESERVE | MEM_COMMIT | MEM_WRITE_WATCH,
                PAGE_READWRITE);
    }

    void* os_mem_filemap(size_t nbytes) nothrow
    {
        HANDLE hMapFile;
        uint hwBytes = cast(uint)((nbytes >> 16) >> 16);
        hMapFile = CreateFileMappingW(INVALID_HANDLE_VALUE,    // use paging file
                                      null,                    // default security
                                      PAGE_READWRITE| SEC_COMMIT, // read/write access
                                      hwBytes,                 // maximum object size (high-order DWORD)
                                      cast(uint)nbytes,        // maximum object size (low-order DWORD)
                                      null);                   // name of mapping object
        return cast(void*)hMapFile;
    }

    void* os_mem_mapview(void* mapfile, size_t nbytes, void* addr) nothrow
    {
        void* p = MapViewOfFileEx(cast(HANDLE)mapfile, FILE_MAP_ALL_ACCESS, 0, 0, nbytes, addr);
        return p;
    }

    bool os_mem_unmapview(void* p, size_t nbytes) nothrow
    {
        return UnmapViewOfFile(p) != 0;
    }

    bool os_mem_filemap(void* mapfile, size_t nbytes) nothrow
    {
        return CloseHandle(cast(HANDLE)mapfile) != 0;
    }

    /**
     * Unmap memory allocated with os_mem_map().
     * Returns:
     *      0       success
     *      !=0     failure
     */
    int os_mem_unmap(void *base, size_t nbytes) nothrow
    {
        return cast(int)(VirtualFree(base, 0, MEM_RELEASE) == 0);
    }

	extern(Windows) UINT GetWriteWatch(DWORD dwFlags, PVOID lpBaseAddress, SIZE_T dwRegionSize,
									   PVOID *lpAddresses, PULONG_PTR lpdwCount, PULONG lpdwGranularity) nothrow;
	extern(Windows) UINT ResetWriteWatch(LPVOID lpBaseAddress, SIZE_T dwRegionSize) nothrow;

    enum WRITE_WATCH_FLAG_RESET = 1;

    void os_mem_resetWriteWatch(void *base, size_t nbytes) nothrow
    {
        ResetWriteWatch(base, nbytes);
    }

    bool os_mem_getWriteWatch(bool reset, void *base, size_t nbytes, void** wraddr, size_t* count, uint* granularity) nothrow
    {
		UINT res = GetWriteWatch(reset ? WRITE_WATCH_FLAG_RESET : false, base, nbytes, wraddr, count, granularity);
		return (res == 0);
    }
}
else static if (is(typeof(mmap)))  // else version (GC_Use_Alloc_MMap)
{
    enum hasMemWriteWatch = false;

    void *os_mem_map(size_t nbytes) nothrow
    {   void *p;

        p = mmap(null, nbytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
        return (p == MAP_FAILED) ? null : p;
    }


    int os_mem_unmap(void *base, size_t nbytes) nothrow
    {
        return munmap(base, nbytes);
    }
}
else static if (is(typeof(valloc))) // else version (GC_Use_Alloc_Valloc)
{
    enum hasMemWriteWatch = false;

    void *os_mem_map(size_t nbytes) nothrow
    {
        return valloc(nbytes);
    }


    int os_mem_unmap(void *base, size_t nbytes) nothrow
    {
        free(base);
        return 0;
    }
}
else static if (is(typeof(malloc))) // else version (GC_Use_Alloc_Malloc)
{
    enum hasMemWriteWatch = false;

    // NOTE: This assumes malloc granularity is at least (void*).sizeof.  If
    //       (req_size + PAGESIZE) is allocated, and the pointer is rounded up
    //       to PAGESIZE alignment, there will be space for a void* at the end
    //       after PAGESIZE bytes used by the GC.


    import gc.gc;


    const size_t PAGE_MASK = PAGESIZE - 1;


    void *os_mem_map(size_t nbytes) nothrow
    {   byte *p, q;
        p = cast(byte *) malloc(nbytes + PAGESIZE);
        q = p + ((PAGESIZE - ((cast(size_t) p & PAGE_MASK))) & PAGE_MASK);
        * cast(void**)(q + nbytes) = p;
        return q;
    }


    int os_mem_unmap(void *base, size_t nbytes) nothrow
    {
        free( *cast(void**)( cast(byte*) base + nbytes ) );
        return 0;
    }
}
else
{
    static assert(false, "No supported allocation methods available.");
}
