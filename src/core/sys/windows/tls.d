module core.sys.windows.tls;

version(Windows):
version(DigitalMars)
{
    version(CRuntime_DigitalMars)
    {
        // NOTE: The memory between the addresses of _tlsstart and _tlsend
        //       is the storage for thread-local data in D 2.0.  Both of
        //       these are defined in dm\src\win32\tlsseg.asm by DMC.
        extern (C)
        {
            extern           byte  _tlsstart;
            extern           byte  _tlsend;
            extern __gshared void* _tls_callbacks_a;
            extern __gshared int   _tls_index;
        }
    }
    version(CRuntime_Microsoft)
    {
        // NOTE: The memory between the addresses of _tls_start and _tls_end
        //       is the storage for thread-local data in D 2.0.  Both of
        //       these are defined in LIBCMT:tlssub.obj
        extern (C)
        {
            extern           byte  _tls_start;
            extern           byte  _tls_end;
            extern __gshared void*  __xl_a;
            extern __gshared int   _tls_index;
        }
        alias _tls_start _tlsstart;
        alias _tls_end   _tlsend;
        alias __xl_a     _tls_callbacks_a;
    }
}
else
{
    __gshared int   _tlsstart;
    alias _tlsstart _tlsend;
}
