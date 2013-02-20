// Public Domain
module dll;

import std.c.windows.windows;
import core.sys.windows.dllclient;
import core.sys.windows.tls;
import std.c.stdio;


extern (Windows)
BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved)
{
    switch (ulReason)
    {
        case DLL_PROCESS_ATTACH:
            return shared_dll_process_attach(hInstance);

        case DLL_PROCESS_DETACH:
            shared_dll_process_detach(hInstance);
            break;

        case DLL_THREAD_ATTACH:
            shared_dll_thread_attach();
            break;

        case DLL_THREAD_DETACH:
            shared_dll_thread_detach();
            break;

        default:
            return false;
    }
    return true;
}

/* --------------------------------------------------------- */

shared static this()
{
    printf("shared static this for dll\n");
}

shared static ~this()
{
    printf("shared static ~this for dll\n");
}

static this()
{
    printf("static this for dll\n");
}

static ~this()
{
    printf("static ~this for dll\n");
}

/* --------------------------------------------------------- */

class DLLClass
{
    string concat(string a, string b)
    {
        return a ~ " " ~ b;
    }

    void free(string s)
    {
        delete s;
    }

    void except(string s)
    {
        printf("dll throwing exception\n");
        throw new Exception(s);
    }
}

export DLLClass getClass()
{
    return new DLLClass();
}
