/**
* Contains the garbage collector configuration.
*
* Copyright: Copyright Digital Mars 2014
* License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
*/

module gc.config;

import core.stdc.stdlib;
import core.stdc.stdio;
import core.stdc.ctype;

struct Config
{
    bool profile;
    bool precise;
    bool concurrent;

    size_t initReserve;      // initial reserve (MB)
    size_t minPoolSize = 1;  // initial and minimum pool size (MB)
    size_t maxPoolSize = 32; // maximum pool size (MB)
    size_t incPoolSize = 2;  // pool size increment (MB)

    bool initialize() @nogc
    {
        auto p = getenv("D_GC");
        if (!p)
            return false;

        while(*p)
        {
            while (*p && isspace(*p))
                p++;
            if (!*p)
                break;
            auto q = p;
            while (*q && *q != '=')
                q++;

            if (*q)
            {
                auto r = q + 1;
                size_t v = 0;
                for ( ; *r >= '0' && *r <= '9'; r++)
                    v = v * 10 + *r - '0';

                char[] s = p[0 .. q - p];
                if(s == "profile")
                    profile = v != 0;
                else if(s == "precise")
                    precise = v != 0;
                else if(s == "concurrent")
                    concurrent = v != 0;
                else if(s == "initReserve")
                    initReserve = v;
                else if(s == "minPoolSize")
                    minPoolSize = v;
                else if(s == "maxPoolSize")
                    maxPoolSize = v;
                else if(s == "incPoolSize")
                    incPoolSize = v;
                else
                    printf("Unknown option \"%.*s\" in environment variable D_GC\n", s.length, s.ptr);
                p = r;
            }
            else
            {
                printf("Incomplete option \"%.*s\" in environment variable D_GC\n", q - p, p);
                p = q;
            }
        }
        return true;
    }
}
