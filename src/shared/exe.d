module exe;

import core.runtime;
import core.thread;
import std.stdio;

import dll;

//version=DYNAMIC_LOAD;

version (DYNAMIC_LOAD)
{
    import std.c.windows.windows;

    alias MyClass function() getMyClass_fp;

    int main()
    {   HMODULE h;
        FARPROC fp;

        getMyClass_fp getMyClass;
        MyClass c;

        printf("Start Dynamic Link...\n");

        h = cast(HMODULE) Runtime.loadLibrary("mydll.dll");
        if (h is null)
        {
            printf("error loading mydll.dll\n");
            return 1;
        }

        fp = GetProcAddress(h, "D5mydll10getMyClassFZC5mydll7MyClass");
        if(!fp)
            fp = GetProcAddress(h, "_D5mydll10getMyClassFZC5mydll7MyClass");
        if (fp is null)
        {   printf("error loading symbol getMyClass()\n");
            return 1;
        }

        getMyClass = cast(getMyClass_fp) fp;
        c = (*getMyClass)();
        foo(c);

        if (!Runtime.unloadLibrary(h))
        {   printf("error freeing mydll.dll\n");
            return 1;
        }

        printf("End...\n");
        return 0;
    }
}
else
{   // static link the DLL

    int main()
    {
        printf("Start Static Link...\n");
        foo(getClass(), "World");

        printf("Starting new thread...\n");
        auto c = new DLLClass;
        auto t = new Thread({ foo(c, "Thread"); });
        t.start();
        t.join();

        try
        {
            c.except("message");
        }
        catch(Exception e)
        {
            writeln("exe caught exception ", e.msg);
        }
        printf("End...\n");
        return 0;
    }
}

void foo(DLLClass c, string who)
{
    string s;

    s = c.concat("Hello", who);
    writefln(s);
    c.free(s);
}

/* --------------------------------------------------------- */

shared static this()
{
    printf("shared static this for exe\n");
}

shared static ~this()
{
    printf("shared static ~this for exe\n");
}

static this()
{
    printf("static this for exe\n");
}

static ~this()
{
    printf("static ~this for exe\n");
}

