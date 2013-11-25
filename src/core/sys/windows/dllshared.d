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
import core.stdc.string;

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
        size_t tls_size;
        ModuleGroup* moduleGroup;
    }
    __gshared dll_data_info[] dll_data;
}

void dll_add_tlsdata( int tls_index, size_t tls_size, ModuleGroup* moduleGroup )
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
    enum IMAGE_OFFSET_TO_FILE_HEADER = 0x3c; // where to read start of IMAGE_FILE_HEADER

    struct IMAGE_FILE_HEADER
    {
        WORD    Machine;
        WORD    NumberOfSections;
        DWORD   TimeDateStamp;
        DWORD   PointerToSymbolTable;
        DWORD   NumberOfSymbols;
        WORD    SizeOfOptionalHeader;
        WORD    Characteristics;
    }

    enum IMAGE_NUMBEROF_DIRECTORY_ENTRIES =    16;

    struct IMAGE_DATA_DIRECTORY
    {
        DWORD   VirtualAddress;
        DWORD   Size;
    }

    struct IMAGE_OPTIONAL_HEADER
    {
        // Standard fields.
        WORD    Magic;
        BYTE    MajorLinkerVersion;
        BYTE    MinorLinkerVersion;
        DWORD   SizeOfCode;
        DWORD   SizeOfInitializedData;
        DWORD   SizeOfUninitializedData;
        DWORD   AddressOfEntryPoint;
        DWORD   BaseOfCode;
        DWORD   BaseOfData;

        // NT additional fields.
        DWORD   ImageBase;
        DWORD   SectionAlignment;
        DWORD   FileAlignment;
        WORD    MajorOperatingSystemVersion;
        WORD    MinorOperatingSystemVersion;
        WORD    MajorImageVersion;
        WORD    MinorImageVersion;
        WORD    MajorSubsystemVersion;
        WORD    MinorSubsystemVersion;
        DWORD   Win32VersionValue;
        DWORD   SizeOfImage;
        DWORD   SizeOfHeaders;
        DWORD   CheckSum;
        WORD    Subsystem;
        WORD    DllCharacteristics;
        SIZE_T   SizeOfStackReserve;
        SIZE_T  SizeOfStackCommit;
        SIZE_T  SizeOfHeapReserve;
        SIZE_T  SizeOfHeapCommit;
        DWORD   LoaderFlags;
        DWORD   NumberOfRvaAndSizes;
        IMAGE_DATA_DIRECTORY DataDirectory[IMAGE_NUMBEROF_DIRECTORY_ENTRIES];
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

    static IMAGE_FILE_HEADER* getImageHeader(HINSTANCE hInstance)
    {
        ubyte* mem = cast(ubyte*) hInstance;
        if(mem[0] != 'M' || mem[1] != 'Z')
            return null;
        int peoff = *cast(uint*)(mem + IMAGE_OFFSET_TO_FILE_HEADER);
        if(peoff >= 4093)
            return null; // sanity check
        if(mem[peoff] != 'P' || mem[peoff+1] != 'E' || mem[peoff+2] != 0 || mem[peoff+3] != 0)
            return null; // wrong signature
        return cast(IMAGE_FILE_HEADER*)(mem + peoff + 4);
    }

    static IMAGE_OPTIONAL_HEADER* getOptionalImageHeader(HINSTANCE hInstance)
    {
        IMAGE_FILE_HEADER* hdr = getImageHeader(hInstance);
        if(!hdr)
            return null;
        return cast(IMAGE_OPTIONAL_HEADER*) (hdr + 1);
    }

    static uint getImageSize(HINSTANCE hInstance)
    {
        IMAGE_OPTIONAL_HEADER* hdr = getOptionalImageHeader(hInstance);
        if(!hdr)
            return 0;
        return hdr.SizeOfImage;
    }

    static IMAGE_DATA_DIRECTORY[] getDataDirectory(HINSTANCE hInstance)
    {
        IMAGE_OPTIONAL_HEADER* hdr = getOptionalImageHeader(hInstance);
        if(!hdr)
            return null;
        return hdr.DataDirectory[0..hdr.NumberOfRvaAndSizes];
    }

    static ubyte[] getImportDirectory(HINSTANCE hInstance)
    {
        IMAGE_DATA_DIRECTORY[] dir = getDataDirectory(hInstance);
        if(!dir)
            return null;

        ubyte* mem = cast(ubyte*) hInstance + dir[1].VirtualAddress;
        return mem[0 .. dir[1].Size];
    }

    static IMAGE_IMPORT_DESCRIPTOR[] getImportDescriptor(HINSTANCE hInstance)
    {
        IMAGE_DATA_DIRECTORY[] dir = getDataDirectory(hInstance);
        if(!dir)
            return null;

        ubyte* mem = cast(ubyte*) hInstance;
        auto imp = cast(IMAGE_IMPORT_DESCRIPTOR*)(mem + dir[1].VirtualAddress);
        uint cnt = 0;
        while(cnt * IMAGE_IMPORT_DESCRIPTOR.sizeof < dir[1].Size && imp[cnt].Characteristics)
            cnt++;
        return imp[0 .. cnt];
    }

    static IMAGE_SECTION_HEADER[] getSections(HINSTANCE hInstance)
    {
        IMAGE_FILE_HEADER* hdr = getImageHeader(hInstance);
        if(!hdr)
            return null;

        auto base = cast(IMAGE_SECTION_HEADER*)(cast(ubyte*)(hdr + 1) + hdr.SizeOfOptionalHeader);
        return base[0..hdr.NumberOfSections];
    }

    static void[] findRelocationSectionInMem(HINSTANCE hInstance)
    {
        try
        {
            void* mem = cast(void*) hInstance;
            IMAGE_SECTION_HEADER[] sections = getSections(hInstance);
            if(sections)
                for(size_t s = 0; s < sections.length; s++)
                    if(memcmp(sections[s].Name.ptr, ".reldata".ptr, 8) == 0)
                        return (mem + sections[s].VirtualAddress)[0 .. sections[s].VirtualSize];
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
            return *ptr;
        return null;
    }

    static ubyte* getImportAdress(ubyte[] impDir, ubyte**ptr)
    {
        if(cast(void*) ptr >= impDir.ptr && cast(void*) ptr <= impDir.ptr + impDir.length - (void*).sizeof)
            return *ptr;
        return null;
    }

    static ubyte*[] getIATrange(HINSTANCE hInstance, ref IMAGE_IMPORT_DESCRIPTOR desc)
    {
        ubyte** adr = cast(ubyte**)(hInstance + desc.FirstThunk);
        int cnt = 0;
        while(adr[cnt])
            cnt++;
        return adr[0 .. cnt];
    }

    static ubyte*[] getIAT(HINSTANCE hInstance, string dllname)
    {
        IMAGE_IMPORT_DESCRIPTOR[] imp = getImportDescriptor(hInstance);

        for(size_t i = 0; i < imp.length; i++)
        {
            char* name = cast(char*)(hInstance + imp[i].Name);
            if(stricmp(name, dllname.ptr) == 0)
                return getIATrange(hInstance, imp[i]);
        }
        return null;
    }

    // memory range over all IAT entries
    static ubyte*[] getIAT(HINSTANCE hInstance)
    {
        IMAGE_IMPORT_DESCRIPTOR[] imp = getImportDescriptor(hInstance);
        if(imp.length == 0)
            return null;

        ubyte*[] rng;
        for(size_t i = 0; i < imp.length; i++)
        {
            ubyte*[] r = getIATrange(hInstance, imp[i]);
            if (rng.length == 0)
                rng = r;
            else if(r.length != 0)
            {
                auto beg = (rng.ptr < r.ptr ? rng.ptr : r.ptr);
                auto end = (rng.ptr + rng.length > r.ptr + r.length ? rng.ptr + rng.length : r.ptr + r.length);
                rng = beg[0 .. end-beg];
            }
        }
        return rng;
    }
}

//version = PRINTF;

public bool dll_patchImportRelocations(HINSTANCE hInstance)
{
version(PRINTF) import core.stdc.stdio;

    void[] reloc = dll_helper_aux2.findRelocationSectionInMem(hInstance);
    if (!reloc.length)
        return true;

    void* memStart = hInstance;
    void* memEnd = hInstance + dll_helper_aux2.getImageSize(hInstance);
    ubyte*[] iat = dll_helper_aux2.getIAT(hInstance);

    DWORD oldProtect;
    BOOL rc = VirtualProtect(memStart, memEnd - memStart, PAGE_EXECUTE_READWRITE, &oldProtect);
    if(!rc)
        return false;

    static struct RelocData
    {
        void** adr;       // points to the memory location where the relocation was applied
        size_t symbolOff; // offset to the symbol in the relocation already applied
    }
    auto reldata = cast(RelocData[]) reloc;

    for(size_t r = 0; r < reldata.length; r++)
    {
        void** adr = reldata[r].adr;
        size_t off = reldata[r].symbolOff;
version(PRINTF) printf("Reloc: adr %p off %p", adr, off);

        if(adr < memStart || adr >= memEnd)
            goto L_next;
        auto symadr = cast(ubyte*) (*adr - off);
        if(symadr < memStart || symadr >= memEnd)
            goto L_next;

        if(symadr[0] == 0xff && symadr[1] == 0x25) // jump through import table?
        {
            symadr += 2; // jmp dword ptr[adr]
            ubyte** ptr = *cast(ubyte***)symadr;
            if(ubyte* impptr = dll_helper_aux2.getImportAdress(iat, ptr))
            {
                *adr = impptr + off;
                version(PRINTF) printf(" patched to %p", impptr + off);
            }
        }
    L_next:
version(PRINTF) printf("\n");
    }

    VirtualProtect(memStart, memStart - memEnd, oldProtect, &oldProtect);
    return true;
}

