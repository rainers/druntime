/**
 * Contains the garbage collector implementation.
 *
 * Copyright: Copyright Digital Mars 2001 - 2013.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, David Friedman, Sean Kelly
 */

/*          Copyright Digital Mars 2005 - 2013.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

// D Programming Language Garbage Collector configuration

module gc.config;

import core.stdc.stdlib;
import core.stdc.stdio;

__gshared bool gc_precise = true;

void gc_config_init()
{
    if(char* penv = getenv("D_GC_PRECISE"))
        gc_precise = (*penv == '1' || *penv == 'Y' || *penv == 'y');

    debug printf("D_GC_PRECISE=%d\n", gc_precise);
}
