// DISABLED: not part of benchmark suite

import std.stdio;
import std.string;
import core.stdc.string;
import core.sys.windows.windows;

enum PAGE_SIZE = 4096;
enum NUM_PAGES = 1024;
enum NUM_DISPLAY = 4;
enum BUF_SIZE = PAGE_SIZE * NUM_PAGES;

extern(Windows) UINT ResetWriteWatch(LPVOID lpBaseAddress, SIZE_T dwRegionSize) nothrow;

enum MEM_WRITE_WATCH = 0x00200000;
enum WRITE_WATCH_FLAG_RESET = 1;

///////////////////////////////////////////////////////////////////////
void benchPageRdRd(string msg, void* pBuf)
{
    int[NUM_PAGES] tmFirstRead;
    int[NUM_PAGES] tmSecondRead;

    version(D_InlineAsm_X86_64)
    asm
    {
        push RSI;
        push RDI;
        push RBX;
        push RCX;

        mov RBX, pBuf;
        //		add EBX, BUF_SIZE - PAGE_SIZE;
        xor RCX, RCX;

        // rdtsc only
        rdtsc; // warm up
        rdtsc;
        rdtsc;
        mov ESI, EAX;
        rdtsc;
        sub EAX,ESI;
        mov EDI,EAX;

    nextPage:
        rdtsc;
        mov ESI, EAX;
        mov EAX, [RBX];
        rdtsc;
        sub EAX,ESI;
        sub EAX,EDI;
        lea RDX,tmFirstRead;
        mov [RDX+4*RCX], EAX;

        rdtsc;
        mov ESI, EAX;
        mov EAX, [RBX+1024];
        rdtsc;
        sub EAX,ESI;
        sub EAX,EDI;
        lea RDX,tmSecondRead;
        mov [RDX+4*RCX], EAX;

        add RBX,PAGE_SIZE;
        inc ECX;
        cmp ECX, NUM_PAGES;
        jl nextPage;

        pop RCX;
        pop RBX;
        pop RDI;
        pop RSI;
    }
    else
    asm
    {
        push ESI;
        push EDI;
        push EBX;
        push ECX;

        mov EBX, pBuf;
        //		add EBX, BUF_SIZE - PAGE_SIZE;
        mov ECX, 0;

        // rdtsc only
        rdtsc; // warm up
        rdtsc;
        rdtsc;
        mov ESI, EAX;
        rdtsc;
        sub EAX,ESI;
        mov EDI,EAX;

    nextPage:
        rdtsc;
        mov ESI, EAX;
        mov EAX, [EBX];
        rdtsc;
        sub EAX,ESI;
        sub EAX,EDI;
        lea EDX,tmFirstRead;
        mov [EDX+4*ECX], EAX;

        rdtsc;
        mov ESI, EAX;
        mov EAX, [EBX+1024];
        rdtsc;
        sub EAX,ESI;
        sub EAX,EDI;
        lea EDX,tmSecondRead;
        mov [EDX+4*ECX], EAX;

        add EBX,PAGE_SIZE;
        inc ECX;
        cmp ECX, NUM_PAGES;
        jl nextPage;

        pop ECX;
        pop EBX;
        pop EDI;
        pop ESI;
    }

    writeln(msg);

    int tmMin = tmFirstRead[0];
    long tmSum = 0;
    for(int i = 0; i < NUM_PAGES; i++)
    {
        if(i < NUM_DISPLAY)
            writefln("  page%d: 1st rd: %d cycles, 2nd rd: %d cycles", i, tmFirstRead[i], tmSecondRead[i]);
        tmMin = tmFirstRead[i] < tmMin ? tmFirstRead[i] : tmMin;
        tmSum += tmFirstRead[i];
    }
    int tmAvg = cast(int) (tmSum / (NUM_PAGES - 1));
    writefln("  minimum: 1st rd: %d cycles, avg %d cycles", tmMin, tmAvg);
}

void benchPageWrWrRd(string msg, void* pBuf)
{
    int[NUM_PAGES] tmFirstWrite;
    int[NUM_PAGES] tmSecondWrite;
    int[NUM_PAGES] tmRead;

    version(D_InlineAsm_X86_64)
    asm
    {
        push RSI;
        push RDI;
        push RBX;
        push RCX;

        mov RBX, pBuf;
        //		add EBX, BUF_SIZE - PAGE_SIZE;
        mov RCX, 0;

        // rdtsc only
        rdtsc; // warm up
        rdtsc;
        rdtsc;
        mov ESI, EAX;
        rdtsc;
        sub EAX,ESI;
        mov EDI,EAX;

    nextPage:
        rdtsc;
        mov ESI, EAX;
        mov [RBX], 0;
        rdtsc;
        sub EAX,ESI;
        sub EAX,EDI;
        lea RDX,tmFirstWrite;
        mov [RDX+4*RCX], EAX;

        rdtsc;
        mov ESI, EAX;
        mov [RBX+1024], 0;
        rdtsc;
        sub EAX,ESI;
        sub EAX,EDI;
        lea RDX,tmSecondWrite;
        mov [RDX+4*RCX], EAX;

        rdtsc;
        mov ESI, EAX;
        mov EAX,[RBX+2048];
        rdtsc;
        sub EAX,ESI;
        sub EAX,EDI;
        lea RDX,tmRead;
        mov [RDX+4*RCX], EAX;

        add RBX,PAGE_SIZE;
        inc ECX;
        cmp ECX, NUM_PAGES;
        jl nextPage;

        pop RCX;
        pop RBX;
        pop RDI;
        pop RSI;
    }
    else
    asm
    {
        push ESI;
        push EDI;
        push EBX;
        push ECX;

        mov EBX, pBuf;
        //		add EBX, BUF_SIZE - PAGE_SIZE;
        mov ECX, 0;

        // rdtsc only
        rdtsc; // warm up
        rdtsc;
        rdtsc;
        mov ESI, EAX;
        rdtsc;
        sub EAX,ESI;
        mov EDI,EAX;

    nextPage:
        rdtsc;
        mov ESI, EAX;
        mov [EBX], 0;
        rdtsc;
        sub EAX,ESI;
        sub EAX,EDI;
        lea EDX,tmFirstWrite;
        mov [EDX+4*ECX], EAX;

        rdtsc;
        mov ESI, EAX;
        mov [EBX+1024], 0;
        rdtsc;
        sub EAX,ESI;
        sub EAX,EDI;
        lea EDX,tmSecondWrite;
        mov [EDX+4*ECX], EAX;

        rdtsc;
        mov ESI, EAX;
        mov EAX,[EBX+2048];
        rdtsc;
        sub EAX,ESI;
        sub EAX,EDI;
        lea EDX,tmRead;
        mov [EDX+4*ECX], EAX;

        add EBX,PAGE_SIZE;
        inc ECX;
        cmp ECX, NUM_PAGES;
        jl nextPage;

        pop ECX;
        pop EBX;
        pop EDI;
        pop ESI;
    }

    writeln(msg);
    int tmMin = tmFirstWrite[0];
    long tmSum = 0;
    for(int i = 0; i < NUM_PAGES; i++)
    {
        if(i < NUM_DISPLAY)
            writefln("  page%d: 1st wr: %5d cycles, 2nd wr: %d cycles, rd: %d cycles", i, tmFirstWrite[i], tmSecondWrite[i], tmRead[i]);
        tmMin = tmFirstWrite[i] < tmMin ? tmFirstWrite[i] : tmMin;
        tmSum += tmFirstWrite[i];
    }
    int tmAvg = cast(int) (tmSum / (NUM_PAGES - 1));
    writefln("  minimum: 1st wr: %d cycles, avg %d cycles", tmMin, tmAvg);
}

///////////////////////////////////////////////////////////////////////
void benchVirtualAlloc(string msg, uint flags)
{
    void* pBuf = VirtualAlloc(null, BUF_SIZE, flags, PAGE_READWRITE);
    if (!pBuf)
        throw new Exception(format("Could not allocate (%d).\n", GetLastError()));

    benchPageWrWrRd(msg, pBuf);

    if (flags & MEM_WRITE_WATCH)
        ResetWriteWatch(pBuf, BUF_SIZE);

    benchPageWrWrRd(msg ~ " again", pBuf);

    VirtualFree(pBuf, 0, MEM_RELEASE);
}

///////////////////////////////////////////////////////////////////////
void benchCopyOnWrite()
{
    HANDLE hMapFile = CreateFileMappingW(INVALID_HANDLE_VALUE,    // use paging file
                                         null,                    // default security
                                         PAGE_READWRITE,          // read/write access
                                         0,                       // maximum object size (high-order DWORD)
                                         BUF_SIZE,                // maximum object size (low-order DWORD)
                                         "benchCOW"w.ptr);        // name of mapping object
    if (!hMapFile)
        throw new Exception(format("Could not create file mapping object (%d).\n", GetLastError()));
    scope(exit) CloseHandle(hMapFile);

    void* pBuf = MapViewOfFile(hMapFile, FILE_MAP_ALL_ACCESS, 0, 0, BUF_SIZE);
    if (!pBuf)
        throw new Exception(format("Could not map view of file (%d).\n", GetLastError()));
    scope(exit) UnmapViewOfFile(pBuf);

    benchPageWrWrRd("shared-memory", pBuf);

    DWORD oldProtect;
    if(!VirtualProtect(pBuf, BUF_SIZE, PAGE_WRITECOPY, &oldProtect))
        throw new Exception(format("Could not protect page (%d).\n", GetLastError()));

    benchPageRdRd("read cow mem ", pBuf);
    benchPageWrWrRd("copy-on-write", pBuf);
}

///////////////////////////////////////////////////////////////////////
struct Cleanup
{
    ~this() 
    { 
        printf("cleanup\n");
    }
}

int benchDException()
{
    int tm1, tm2;
    try
    {
        auto e = new Exception("");
        asm { rdtsc; mov tm1, EAX; }
        throw e;
    }
    catch(Exception e)
    {
        asm { rdtsc; mov tm2, EAX; }
    }
    return tm2 - tm1;
}

int benchThrowable()
{
    int tm1, tm2;
    try
    {
        asm { 
            rdtsc; 
            mov tm1, EAX; 

            mov EAX, 0;
            mov [EAX], 0;
        }
    }
    catch(Throwable e)
    {
        asm { rdtsc; mov tm2, EAX; }
    }
    return tm2 - tm1;
}

///////////////////////////////////////////////////////////////////////
enum EXCEPTION_DISPOSITION
{
    ExceptionContinueExecution,
    ExceptionContinueSearch,
    ExceptionNestedException,
    ExceptionCollidedUnwind
}
struct EXCEPTION_RECORD;

__gshared int tmExceptHandler;
__gshared int scratchMem;
__gshared int hookReturnImediately;

int benchExceptionHandler(out int usercb)
{
    static extern(C) 
    int _except_handler(EXCEPTION_RECORD *ExceptionRecord, void * EstablisherFrame,
                        CONTEXT *ContextRecord, void * DispatcherContext)
    {
        asm { rdtsc; mov tmExceptHandler, EAX; }
        version(D_LP64)
            ContextRecord.Rax = cast(size_t) &scratchMem; // patch EAX to point to valid memory
        else
            ContextRecord.Eax = cast(size_t) &scratchMem; // patch EAX to point to valid memory
        return EXCEPTION_DISPOSITION.ExceptionContinueExecution;
    }

    void* pBuf = VirtualAlloc(null, BUF_SIZE, MEM_COMMIT | MEM_RESERVE, PAGE_READONLY);
    if (!pBuf)
        throw new Exception(format("Could not allocate (%d).\n", GetLastError()));

    hookReturnImediately = 1;
    int tmException, tmReturn;
    version(D_InlineAsm_X86_64)
    asm
    {
        rdtsc; 
        mov tmException, EAX;

        mov     RAX, pBuf;
        mov     [RAX], 0;       // cause write access fault

        rdtsc; 
        mov tmReturn, EAX;
    }
    else
    asm
    {                             // Build EXCEPTION_REGISTRATION record:
        mov     EAX,offsetof _except_handler;
        push    EAX;              // Address of handler function
        push    dword ptr FS:[0]; // Address of previous handler
        mov     FS:[0],ESP;       // Install new EXECEPTION_REGISTRATION

        rdtsc; 
        mov tmException, EAX;

        mov     EAX, pBuf;
        mov     [EAX], 0;       // cause write access fault

        rdtsc; 
        mov tmReturn, EAX;

        mov     EAX,[ESP];      // Get pointer to previous record
        mov     FS:[0], EAX;    // Install previous record
        add     ESP, 8;         // Clean our EXECEPTION_REGISTRATION off stack
    }
    hookReturnImediately = 0;

    VirtualFree(pBuf, 0, MEM_RELEASE);

    int tm = tmReturn - tmException;
    usercb =  tmExceptHandler - tmException;
    return tm;
}

bool patchKiUserExceptionDispatcher()
{
    __gshared void* oldaddr, newaddr;
    void* cpyadr;
    // todo: need to find a way to get the address of KiUserExceptionDispatcher
    version(Win64)
    {
        void* addr = cast(void*) 0x00007FFACFB4C9C0;
        oldaddr = addr + 0x60;
        asm
        {
            call getEIP; // aaargh, cannot get address of label
        getEIP:
            pop RAX;
            add RAX, 14;
            mov newaddr, RAX;
            jmp cont1;

        hookAddr:
            rdtsc;
            mov tmExceptHandler, EAX;
            mov EAX, hookReturnImediately;
            or EAX,EAX;
            je continueHandler;
            lea RAX,scratchMem;
            mov [RSP+0x78], RAX;  // modify RAX in context
            mov RAX,[oldaddr];
            sub RAX,0x2e;
            jmp RAX;
        continueHandler:
            jmp [oldaddr];

        cont1:;
        }
    }
    else
    {
        void* addr = cast(void*) 0x7731F35C;
        oldaddr = addr + 8;
        asm
        {
            call getEIP; // aaargh, cannot get address of label
        getEIP:
            pop EAX;
            add EAX, 9;
            mov cpyadr, EAX;
            jmp cont1;

        copyAddr:
            nop; nop; nop; nop;
            nop; nop; nop; nop;
            jmp [oldaddr];

        cont1:;
        }
    }
    
    DWORD oldprot;
    VirtualProtect(cast(void*)cpyadr, 1024, PAGE_EXECUTE_READWRITE, &oldprot);
    VirtualProtect(cast(void*)addr, 1024, PAGE_EXECUTE_READWRITE, &oldprot);

    version(Win64)
    asm
    {
        mov RAX, addr;
        mov EDX,[RAX];
        mov [RAX+0x60],EDX;
        mov EDX,[RAX+4];
        sub EDX,0x60;
        mov [RAX+0x64],EDX;
        mov [RAX+0x68],0x9EEB; // jmp addr+8

        mov [RAX],0x51EB; // jmp addr+0x53
        mov word ptr [RAX+0x53],0xb848; // mov EAX,hookaddr
        mov RDX,[newaddr];
        mov [RAX+0x55],RDX;
        mov word ptr [RAX+0x5d],0xFF48; // jmp RAX
        mov byte ptr [RAX+0x5f],0xE0; // jmp RAX
    }
    else
    asm
    {
        mov EAX, cpyadr;
        mov EDX, addr;
        mov EDX, [EDX];
        mov [EAX], EDX;
        mov EDX, addr;
        mov EDX, [EDX+4];
        mov [EAX+4], EDX; // valid instruction sequence is 8 bytes at KiUserExceptionDispatcher

        call getHookAdr;
        mov [newaddr], EAX;

        call getPatchAdr;
        mov EDX, addr;
        mov EAX, [EAX];
        mov [EDX], EAX;
        call getPatchAdr;
        mov EAX, [EAX+4];
        mov [EDX+4], EAX;
        jmp cont;

    getPatchAdr:
        call getEIP2;
    getEIP2:
        pop EAX;
        add EAX,5;
        ret;

    patch:
        jmp [newaddr];
        nop;
        nop;

    getHookAdr:
        call getEIP3;
    getEIP3:
        pop EAX;
        add EAX,5;
        ret;

    hook:
        rdtsc;
        mov tmExceptHandler, EAX;
        mov EAX, hookReturnImediately;
        or EAX,EAX;
        je copyAddr;
        cld;
        mov ECX,dword ptr [ESP+4];
        mov EBX,dword ptr [ESP];
        mov [ECX+0xb0], offsetof scratchMem;
        mov EAX, oldaddr;
        add EAX, 13;
        jmp EAX;
    cont:;
    }
    return true;
}

void benchExceptions()
{
    int[NUM_PAGES] tmWrite;
    int[NUM_PAGES] tmCb;

    for(int i = 0; i < NUM_PAGES; i++)
        tmWrite[i] = benchExceptionHandler(tmCb[i]);

    int tmMin = tmWrite[0];
    int cbMin = tmCb[0];
    writefln("  pass0: handler: %d cycles, write op: %d cycles", tmCb[0], tmWrite[0]);
    long tmSum = 0;
    long tmSum2 = 0;
    for(int i = 1; i < NUM_PAGES; i++)
    {
        if(i < NUM_DISPLAY)
            writefln("  pass%d: handler: %d cycles, write op: %d cycles", 1, tmCb[i], tmWrite[i]);
        tmMin = tmWrite[i] < tmMin ? tmWrite[i] : tmMin;
        cbMin = tmCb[i] < cbMin ? tmCb[i] : cbMin;
        tmSum += tmCb[i];
        tmSum2 += tmWrite[i];
    }
    int tmAvg = cast(int) (tmSum / (NUM_PAGES - 1));
    int tmAvg2 = cast(int) (tmSum2 / (NUM_PAGES - 1));
    writefln("  handler: min %d, avg %d cycles, write op: min %d, avg %d cycles", cbMin, tmAvg, tmMin, tmAvg2);
}

void writeExceptions(int[] tm)
{
    writefln("  pass0: %d cycles", tm[0]);
    int tmMin = tm[0];
    long tmSum = 0;
    for(int i = 1; i < NUM_PAGES; i++)
    {
        if(i < NUM_DISPLAY)
            writefln("  pass%d: %d cycles", i, tm[i]);
        tmMin = tm[i] < tmMin ? tm[i] : tmMin;
        tmSum += tm[i];
    }
    int tmAvg = cast(int) (tmSum / (NUM_PAGES - 1));
    writefln("  minimum %d cycles, avg %d cycles", tmMin, tmAvg);
}

///////////////////////////////////////////////////////////////////////
int main(string[] argv)
{
    SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_TIME_CRITICAL); // avoid being intercepted

    benchVirtualAlloc("VAlloc normal", MEM_COMMIT | MEM_RESERVE);
    benchVirtualAlloc("VAlloc watchd", MEM_COMMIT | MEM_RESERVE | MEM_WRITE_WATCH);
    benchCopyOnWrite();

    int[NUM_PAGES] tm;
    version(Win32)
    {
        for(int i = 0; i < NUM_PAGES; i++)
            tm[i] = benchThrowable();
        writefln("D throwable:");
        writeExceptions(tm);
    }

    for(int i = 0; i < NUM_PAGES; i++)
        tm[i] = benchDException();
    writefln("D exception:");
    writeExceptions(tm);

    version(Win32)
    {
        writeln("write fault with exception handler:");
        benchExceptions();
    }
    writeln("write fault with user mode hook:");
    patchKiUserExceptionDispatcher();
    benchExceptions();

    return 0;
}
