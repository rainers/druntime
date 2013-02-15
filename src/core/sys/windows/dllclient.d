module core.sys.windows.dllclient;

version(Windows):
import core.sys.windows.windows;

// implementation
version(druntime_sharedrtl) {
import core.sys.windows.dllshared;
import core.sys.windows.dll;
import core.sys.windows.tls;

import core.runtime;
import rt.minfo;
import rt.memory;

// patch relocations, fixup TLS storage, initialize runtime of a DLL using 
//  shared RTL and init module ctors and tls ctors for existing threads
// to be called from DllMain with reason DLL_PROCESS_ATTACH
bool shared_dll_process_attach( HINSTANCE hInstance, 
                                void* tlsstart, void* tlsend, void* tls_callbacks_a, int* tlsindex )
{
    dll_patchImportRelocations(hInstance);
    if( !dll_fixTLS( hInstance, tlsstart, tlsend, tls_callbacks_a, tlsindex ) )
        return false;

    dll_add_tlsdata(*tlsindex, tlsend - tlsstart, &_moduleGroup);
    initStaticDataGC();
    _minit();
    rt_moduleCtor();
    rt.minfo.rt_moduleTlsCtor();

    // run tls ctors for all other threads
    void* ctx = cast(void*) GetCurrentThreadId();
    return enumProcessThreads(
        function (uint id, void* context) { 
            if (cast(uint) context != id)
                impersonate_thread( id, &rt.minfo.rt_moduleTlsCtor );
            return true; 
        }, ctx );
}

// to be called from DllMain with reason DLL_PROCESS_ATTACH
// same as above, but takes tls-values from current static linkage
// (actually it does not make sense to call shared_dll_process_attach differently,
//  because it calls other functions like _minit and _moduleCtor, which are
//  always statically linked anyway)
bool shared_dll_process_attach( HINSTANCE hInstance )
{
    return shared_dll_process_attach( hInstance, &_tlsstart, &_tlsend, &_tls_callbacks_a, &_tls_index );
}

// to be called from DllMain with reason DLL_PROCESS_DETACH
void shared_dll_process_detach( HINSTANCE hInstance, int tls_index )
{
    // run tls dtors for all other threads
    void* ctx = cast(void*) GetCurrentThreadId();
    enumProcessThreads(
        function (uint id, void* context) { 
            if (cast(uint) context != id)
                impersonate_thread( id, &rt.minfo.rt_moduleTlsDtor );
            return true; 
        }, ctx );

    rt.minfo.rt_moduleTlsDtor();
    rt_moduleDtor();
    dll_remove_tlsdata(tls_index);
}

// to be called from DllMain with reason DLL_PROCESS_DETACH
// same as above, but takes _tls_index from current static linkage
// (actually it does not make sense to call shared_dll_process_detach differently,
//  because it calls other functions like _moduleTlsDtor and _moduleDtor, which are
//  always statically linked anyway)
void shared_dll_process_detach(HINSTANCE hInstance)
{
    shared_dll_process_detach(hInstance, _tls_index);
}

void shared_dll_thread_attach()
{
    //if(!_moduleinfo_tlsdtors_i)
    //rt.minfo.rt_moduleTlsCtor();
}

void shared_dll_thread_detach()
{
    //rt.minfo.rt_moduleTlsCtor();
}

void shared_dll_add_tlsdata()
{
    dll_add_tlsdata(_tls_index, _tlsend - _tlsstart, &_moduleGroup);
}

void shared_dll_remove_tlsdata()
{
    dll_remove_tlsdata(_tls_index);
}

void shared_dll_patchImportRelocations(HMODULE mod)
{
    dll_patchImportRelocations(mod);
}

}
else // !version(druntime_sharedrtl)
{
    // declare the public interface
    bool shared_dll_process_attach( HINSTANCE hInstance );
    void shared_dll_process_detach( HINSTANCE hInstance );
    void shared_dll_thread_attach();
    void shared_dll_thread_detach();
    void shared_dll_patchImportRelocations( HMODULE mod );
}
