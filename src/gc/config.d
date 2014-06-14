/**
* Contains the garbage collector configuration.
*
* Copyright: Copyright Digital Mars 2014
* License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
*/

module gc.config;

// to add the possiblity to configure the GC from the outside, add gc.config
//  with one of these versions to the executable build command line, e.g.
//      dmd -version=initGCFromEnvironment main.c /path/to/druntime/src/gc/config.d

//version = initGCFromEnvironment; // read settings from environment variable D_GC
//version = initGCFromCommandLine; // read settings from command line argument "--gcopt=options"

version(initGCFromEnvironment)
    version = configurable;
version(initGCFromCommandLine)
    version = configurable;

import core.stdc.stdlib;
import core.stdc.stdio;
import core.stdc.ctype;
import core.stdc.string;
import core.vararg;

extern (C) string[] rt_args();

struct Config
{
    bool disable;            // start disabled
    bool profile;            // enable profiling with summary when terminating program
    bool precise;            // enable precise scanning
    bool concurrent;         // enable concurrent collection
    bool finalCollect = true; // run a collection before program termination

    size_t initReserve;      // initial reserve (MB)
    size_t minPoolSize = 1;  // initial and minimum pool size (MB)
    size_t maxPoolSize = 32; // maximum pool size (MB)
    size_t incPoolSize = 2;  // pool size increment (MB)

    bool initialize(...) // avoid inlining
    {
        version(initGCFromEnvironment)
        {
            auto p = getenv("D_GC");
            if (p)
                if (!parseOptions(p[0 .. strlen(p)]))
                    return false;
        }
        version(initGCFromCommandLine)
        {
            auto args = rt_args();
            foreach (a; args)
                if(a.length > 8 && a[0..8] == "--gcopt=")
                {
                    if (!parseOptions(a[8 .. $]))
                        return false;
                    // TODO: remove argument from args passed to main
                }
        }
        return true;
    }

    version (configurable):

    string help() @nogc
    {
        return "GC options are specified as white space separated assignments:
    disable=0|1      - start disabled
    profile=0|1      - enable profiling with summary when terminating program
    precise=0|1      - enable precise scanning (not implemented yet)
    concurrent=0|1   - enable concurrent collection
    finalCollect=0|1 - run a collection before the program terminates

    initReserve=N    - initial memory to reserve (MB), default 0
    minPoolSize=N    - initial and minimum pool size (MB), default 1
    maxPoolSize=32   - maximum pool size (MB), default 32
    incPoolSize=2    - pool size increment (MB), defaut 2
";
    }

    bool parseOptions(const(char)[] opt) @nogc
    {
        size_t p = 0;
        while(p < opt.length)
        {
            while (p < opt.length && isspace(opt[p]))
                p++;
            if (p >= opt.length)
                break;
            auto q = p;
            while (q < opt.length && opt[q] != '=' && !isspace(opt[q]))
                q++;

            auto s = opt[p .. q];
            if(s == "help")
            {
                printf("%s", help().ptr);
                p = q;
            }
            else if (q < opt.length)
            {
                auto r = q + 1;
                size_t v = 0;
                for ( ; r < opt.length && isdigit(opt[r]); r++)
                    v = v * 10 + opt[r] - '0';

                if(s == "disable")
                    disable = v != 0;
                else if(s == "profile")
                    profile = v != 0;
                else if(s == "precise")
                    precise = v != 0;
                else if(s == "concurrent")
                    concurrent = v != 0;
                else if(s == "finalCollect")
                    finalCollect = v != 0;
                else if(s == "initReserve")
                    initReserve = v;
                else if(s == "minPoolSize")
                    minPoolSize = v;
                else if(s == "maxPoolSize")
                    maxPoolSize = v;
                else if(s == "incPoolSize")
                    incPoolSize = v;
                else
                {
                    printf("Unknown GC option \"%.*s\"\n", cast(int) s.length, s.ptr);
                    return false;
                }
                p = r;
            }
            else
            {
                printf("Incomplete GC option \"%.*s\"\n", cast(int) s.length, s.ptr);
                return false;
            }
        }
        return true;
    }
}
