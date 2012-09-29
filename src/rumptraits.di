module rumptraits;

///////////////////////////////////////////////////////////////////////
// some basic type traits helper
template Unqual(T)
{
    version (none) // Error: recursive alias declaration @@@BUG1308@@@
    {
             static if (is(T U == const U)) alias Unqual!U Unqual;
        else static if (is(T U == immutable U)) alias Unqual!U Unqual;
        else static if (is(T U == inout U)) alias Unqual!U Unqual;
        else static if (is(T U == shared U)) alias Unqual!U Unqual;
        else alias T Unqual;
    }
    else // workaround
    {
             static if (is(T U == shared(const U))) alias U Unqual;
        else static if (is(T U == const U )) alias U Unqual;
        else static if (is(T U == immutable U )) alias U Unqual;
        else static if (is(T U == inout U )) alias U Unqual;
        else static if (is(T U == shared U )) alias U Unqual;
        else alias T Unqual;
    }
}

template TypeTuple(TList...)
{
    alias TList TypeTuple;
}

bool isBasicType(T)()
{
    foreach(t; TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong,
                          float, double, real,
                          ifloat, idouble, ireal,
                          cfloat, cdouble, creal,
                          char, wchar, dchar, bool))
        static if(is(T == t))
            return true;
    return false;
}

