module core.rt.dllmain;

import std.c.windows.windows;
import core.sys.windows.dll;

extern (Windows)
BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved)
{
    switch (ulReason)
    {
        case DLL_PROCESS_ATTACH:
            if(!dll_process_attach(hInstance, true))
                return false;
            break;

        case DLL_PROCESS_DETACH:
            dll_process_detach(hInstance, true);
            break;

        case DLL_THREAD_ATTACH:
            if(!dll_thread_attach(true, true))
                return false;
            break;

        case DLL_THREAD_DETACH:
            dll_thread_detach(true, true);
            break;
            
        default:
            assert(false);
    }
    return true;
}

