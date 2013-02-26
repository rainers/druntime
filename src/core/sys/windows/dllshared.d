/**
* This module provides OS specific helper function for DLL support
*
* Copyright: Copyright Digital Mars 2010 - 2012.
* License: Distributed under the
*      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
*    (See accompanying file LICENSE)
* Authors:   Rainer Schuetze
* Source: $(DRUNTIMESRC src/core/sys/windows/_dll.d)
*/

module core.sys.windows.dllshared;

version(Windows):
import core.sys.windows.windows;
import core.sys.windows.dll;
import core.sys.windows.threadaux;

import core.runtime;
import rt.minfo;
import rt.memory;

extern(C) int stricmp(const(char)*s1, const(char)*s2); // from snn.lib, missing in core.stdc.string

///////////////////////////////////////////////////////////////////
// support for DLL/EXE using shared phobos
private
{
    struct dll_data_info
    {
        int tls_index;
        int tls_size;
        ModuleGroup* moduleGroup;
    }
    __gshared dll_data_info[] dll_data;
}

void dll_add_tlsdata( int tls_index, int tls_size, ModuleGroup* moduleGroup )
{
    // data segment added to gc by addRange
    dll_data_info info = dll_data_info( tls_index, tls_size, moduleGroup );
    dll_data ~= info;
}

void dll_remove_tlsdata( int tls_index )
{
    for( int i = 0; i < dll_data.length; i++ )
        if( dll_data[i].tls_index == tls_index )
        {
            if( i < dll_data.length - 1 )
                dll_data[i] = dll_data[$ - 1];
            dll_data.length = dll_data.length - 1;
            break;
        }
}

private alias void delegate( void*, void* ) scanAllThreadsFn;

void dll_scan_tls( HANDLE thnd, scanAllThreadsFn scan )
{
    if( dll_data.length > 0 )
        if( void** teb = getTEB( thnd ) )
            if( void** tlsarray = cast(void**) teb[11] )
                foreach( ref dll_data_info data; dll_data )
                    scan( teb[data.tls_index], teb[data.tls_index] + data.tls_size );
}

void dll_moduleTlsCtor()
{
    foreach( ref dll_data_info data; dll_data )
        data.moduleGroup.runTlsCtors();
}

void dll_moduleTlsDtor()
{
    foreach_reverse( ref dll_data_info data; dll_data )
        data.moduleGroup.runTlsDtors();
}

///////////////////////////////////////////////////////////////////
// patch relocations through import table

private struct dll_helper_aux2
{
    // don't let symbols leak into other modules

    // binary image information (from winnt.h)
    struct IMAGE_DATA_DIRECTORY
    {
        DWORD   VirtualAddress;
        DWORD   Size;
    }

    struct IMAGE_SECTION_HEADER {
        char    Name[8];
        union {
            DWORD   PhysicalAddress;
            DWORD   VirtualSize;
        }
        DWORD   VirtualAddress;
        DWORD   SizeOfRawData;
        DWORD   PointerToRawData;
        DWORD   PointerToRelocations;
        DWORD   PointerToLinenumbers;
        WORD    NumberOfRelocations;
        WORD    NumberOfLinenumbers;
        DWORD   Characteristics;
    }

    union IMAGE_THUNK_DATA32
    {
        DWORD ForwarderString;      // PBYTE 
        DWORD Function;             // PDWORD
        DWORD Ordinal;
        DWORD AddressOfData;        // PIMAGE_IMPORT_BY_NAME
    }

    struct IMAGE_IMPORT_DESCRIPTOR
    {
        union {
            DWORD   Characteristics;            // 0 for terminating null import descriptor
            DWORD   OriginalFirstThunk;         // RVA to original unbound IAT (PIMAGE_THUNK_DATA)
        };
        DWORD   TimeDateStamp;                  // 0 if not bound,
        // -1 if bound, and real date\time stamp
        //     in IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT (new BIND)
        // O.W. date/time stamp of DLL bound to (Old BIND)
        DWORD   ForwarderChain;                 // -1 if no forwarders
        DWORD   Name;
        DWORD   FirstThunk;                     // RVA to IAT (if bound this IAT has actual addresses)
    }

    static uint getImageSize(HINSTANCE hInstance)
    {
        ubyte* mem = cast(ubyte*) hInstance;
        if(mem[0] != 'M' || mem[1] != 'Z')
            return 0;
        int peoff = *cast(uint*)(mem + 0x3c);
        if(mem[peoff] != 'P' || mem[peoff + 1] != 'E')
            return 0;

        return *cast(uint*)(mem + peoff + 20*4); // SizeOfImage
    }

    static IMAGE_DATA_DIRECTORY[] getDataDirectory(HINSTANCE hInstance)
    {
        ubyte* mem = cast(ubyte*) hInstance;
        if(mem[0] != 'M' || mem[1] != 'Z')
            return null;
        int peoff = *cast(uint*)(mem + 0x3c);
        if(mem[peoff] != 'P' || mem[peoff + 1] != 'E')
            return null;

        return (cast(IMAGE_DATA_DIRECTORY*)(mem + peoff + 0x78))[0..16];
    }

    static ubyte[] getImportDirectory(HINSTANCE hInstance)
    {
        IMAGE_DATA_DIRECTORY[] dir = getDataDirectory(hInstance);

        ubyte* mem = cast(ubyte*) hInstance + dir[1].VirtualAddress;
        return mem[0 .. dir[1].Size];
    }

    static IMAGE_IMPORT_DESCRIPTOR[] getImportDescriptor(HINSTANCE hInstance)
    {
        IMAGE_DATA_DIRECTORY[] dir = getDataDirectory(hInstance);

        ubyte* mem = cast(ubyte*) hInstance;
        auto imp = cast(IMAGE_IMPORT_DESCRIPTOR*)(mem + dir[1].VirtualAddress);
        uint cnt = 0;
        while(cnt * IMAGE_IMPORT_DESCRIPTOR.sizeof < dir[1].Size && imp[cnt].Characteristics)
            cnt++;
        return imp[0 .. cnt];
    }

    static void[] findRelocationSectionInMem(HINSTANCE hInstance)
    {
        try
        {
            IMAGE_DATA_DIRECTORY[] dir = getDataDirectory(hInstance);

            // read relocation entry in data directory
            void* mem = cast(void*) hInstance;
            return (mem + dir[5].VirtualAddress)[0 .. dir[5].Size];
        }
        catch(Exception e)
        {
        }
        return null;
    }

    static ubyte* getImportAdress(ubyte*[] iat, ubyte**ptr)
    {
        size_t idx = ptr - iat.ptr;
        if(idx < iat.length)
            return iat[idx];
        return null;
    }

    static ubyte* getImportAdress(ubyte[] impDir, ubyte**ptr)
    {
        if(cast(void*) ptr >= impDir.ptr && cast(void*) ptr <= impDir.ptr + impDir.length - (void*).sizeof)
            return *ptr;
        return null;
    }

    static ubyte*[] getIAT(HINSTANCE hInstance, string dllname)
    {
        IMAGE_IMPORT_DESCRIPTOR[] imp = getImportDescriptor(hInstance);

        for(int i = 0; i < imp.length; i++)
        {
            char* name = cast(char*)(hInstance + imp[i].Name);
            if(stricmp(name, dllname.ptr) == 0)
            {
                ubyte** adr = cast(ubyte**)(hInstance + imp[i].FirstThunk);
                int cnt = 0;
                while(adr[cnt])
                    cnt++;
                return adr[0 .. cnt];
            }
        }
        return null;
    }

    // use function instead of delegate to avoid allocation for closure
    static void iterateRelocations(HINSTANCE hInstance, void* context, void function (void* context, uint rva) fn)
    {
        void[] reloc = findRelocationSectionInMem(hInstance);
        if (!reloc.length)
            return;

        void* relocbase = reloc.ptr;
        void* relocend = reloc.ptr + reloc.length;
        while(relocbase < relocend)
        {
            uint virtadr = *cast(uint*) relocbase;
            uint chksize = *cast(uint*) (relocbase + 4);

            for (uint p = 8; p < chksize; p += 2)
            {
                ushort entry = *cast(ushort*)(relocbase + p);
                ushort type = (entry >> 12) & 0xf;
                ushort off = entry & 0xfff;

                if(type == 3) // HIGHLOW
                    fn(context, virtadr + off);
            }
            relocbase += chksize;
        }
    }
}

// version = PRINTF;

public void dll_patchImportRelocations(HINSTANCE hInstance)
{
    static struct Context
    {
        void* memStart;
        void* memEnd;
        ubyte*[] iat;
        ubyte[] impDir;
    }

    Context ctx;
    ctx.memStart = hInstance;
    ctx.memEnd = hInstance + dll_helper_aux2.getImageSize(hInstance);
    ctx.impDir = dll_helper_aux2.getImportDirectory(hInstance);

    //ctx.iat = dll_helper_aux2.getIAT(hInstance, "druntime_shared.dll");
    //if(!ctx.iat)
    //    return;

    import core.stdc.stdio;

    DWORD oldProtect;
    BOOL rc = VirtualProtect(ctx.memStart, ctx.memEnd - ctx.memStart, PAGE_EXECUTE_READWRITE, &oldProtect);
    if(!rc)
        return;

version(PRINTF) printf("Ctx.Mem: %p - %p\n", ctx.memStart, ctx.memEnd);
version(PRINTF) printf("Ctx.IAT: %p - %p\n", ctx.iat.ptr, ctx.iat.ptr + ctx.iat.length);

    dll_helper_aux2.iterateRelocations(hInstance, &ctx,
        function void (void* context, uint rva)
        {
            Context* ctx = cast(Context*) context;
            ubyte* adr = *cast(ubyte**)(ctx.memStart + rva);
version(PRINTF) printf("Reloc: RVA %p to %p", ctx.memStart + rva, adr);
            if(adr >= ctx.memStart && adr < ctx.memEnd - 5) // need at least 6 following bytes
            {
                if(adr[0] == 0xff && adr[1] == 0x25)
                {
                    adr += 2; // jmp dword ptr[adr]
                    ubyte** ptr = *cast(ubyte***)adr;
                    if(ubyte* impptr = dll_helper_aux2.getImportAdress(ctx.impDir, ptr))
                    {
                        *cast(ubyte**)(ctx.memStart + rva) = impptr;
version(PRINTF) printf(" patched to %p", impptr);
                    }
                }
                else
                {
                    static struct Info { uint magic; uint size; ubyte* impadr; }
                    Info* info;
                    uint off = adr[0];
                    if((off & 0x80) == 0)
                        info = cast(Info*) (adr + off);
                    else
                    {
                        // skip to next start of UTF8 sequence
                        ubyte* nadr = adr;
                        for(int c = 0; c < 5 && (nadr[0] & 0xC0) == 0xC0; c++)
                            nadr++;
                        if((nadr[0] & 0xC0) == 0x80) // last byte?
                        {
                            nadr++;
                            off = nadr[0];
                            if((off & 0x80) != 0)
                            {
                                if((off & 0xC0) == 0xC0)
                                {
                                    off = off & 0x3f;
                                    for(int c = 0; c < 5 && (nadr[0] & 0xC0) == 0xC0; c++)
                                        off = (off << 6) | (off & 0x3f);
                                    if((nadr[0] & 0xC0) == 0x80) // last byte?
                                    {
                                        off = (off << 6) | (off & 0x3f);
                                        info = cast(Info*) (adr + off);
                                    }
                                }
                            }	
                        }
                    }
                    if(info >= ctx.memStart && info <= ctx.memEnd - info.sizeof)
                    {
                        ubyte* base = cast(ubyte*)info - info.size;
                        if(info.magic == 0xBAFAFADE && base <= adr)
                        {
                            ubyte* iadr = info.impadr;
                            // iadr already the target, if the info struct was already patched
                            if(iadr >= ctx.memStart && iadr < ctx.memEnd - 5) // need at least 6 following bytes
                            {
                                if(iadr[0] == 0xff && iadr[1] == 0x25)
                                {
                                    iadr += 2; // jmp dword ptr[adr]
                                    ubyte** ptr = *cast(ubyte***)iadr;
                                    iadr = dll_helper_aux2.getImportAdress(ctx.impDir, ptr);
                                }
                            }
                            if (iadr)
                            {
                                *cast(ubyte**)(ctx.memStart + rva) = iadr + (adr - base);
version(PRINTF) printf(" patched to %p", iadr + (adr - base));
                            }
                        }
                    }
                }
            }
version(PRINTF) printf("\n");
        });

    VirtualProtect(ctx.memStart, ctx.memStart - ctx.memEnd, oldProtect, &oldProtect);
}

