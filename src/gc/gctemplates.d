/**
* generate RTInfo for precise garbage collector
*
* Copyright: Copyright Digital Mars 2012 - 2013.
* License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
* Authors:   Rainer Schuetze
*/

/*          Copyright Digital Mars 2005 - 2013.
* Distributed under the Boost Software License, Version 1.0.
*    (See accompanying file LICENSE or copy at
*          http://www.boost.org/LICENSE_1_0.txt)
*/
module gc.gctemplates;

// version = RTInfoPRINTF; // want some compile time debug output?
enum bool RTInfoMark__Monitor = false; // is __monitor GC allocated?

///////////////////////////////////////////////////////////////////////
// some basic type traits helper (could use recursive declaration,
// but prevented by @@@BUG1308@@@, see std.traits.Unqual)
template Unqual(T)
{
         static if (is(T U == shared(const U))) alias U Unqual;
    else static if (is(T U == const U )) alias U Unqual;
    else static if (is(T U == immutable U )) alias U Unqual;
    else static if (is(T U == inout U )) alias U Unqual;
    else static if (is(T U == shared U )) alias U Unqual;
    else alias T Unqual;
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

///////////////////////////////////////////////////////////////////////

enum bytesPerPtr        = (void*).sizeof;
enum ptrPerBitmapWord   = 8 * size_t.sizeof;
enum bytesPerBitmapWord = bytesPerPtr * ptrPerBitmapWord;

template allocatedSize(T)
{
    static if (is (T == class))
        enum allocatedSize = __traits(classInstanceSize, T);
    else
        enum allocatedSize = T.sizeof;
}

template bitmapSize(T)
{
    // returns the amount of size_t:s needed to accommodate for the bitmap.
    enum bitmapSize = (allocatedSize!T + bytesPerBitmapWord - 1) / bytesPerBitmapWord;
}

////////////////////////////////////////////////////////
template RTInfoImpl(T)
{
    enum RTInfoImpl = RTInfoImpl2!T.ptr;
}

template RTInfoImpl2(T)
{
    immutable RTInfoImpl2 = bitmap!T();
}

// first element is size of the object that the bitmap corresponds to in bytes.
size_t[bitmapSize!T + 1] bitmap(T)()
{
    size_t[bitmapSize!T + 1] A;
    bitmapImpl!(Unqual!T)(A.ptr + 1);
    A[0] = allocatedSize!T;
    return A;
}

void bitmapImpl(T)(size_t* p)
{
    static if(is(T == class))
    {
        // mark virtual function table ptr? no, it's usually in _DATA
        // mark mutex member __monitor? depends..., usually calloced
        static if(RTInfoMark__Monitor)
            gctemplates_setbit(p, bytesPerPtr);
        mkBitmapComposite!(T)(p, 0);
    }
    else
        mkBitmap!(Unqual!T)(p, 0);
}

version(RTInfoPRINTF) string totext(size_t x)
{
    string s;
    while(x > 9)
    {
        s = ('0' + (x % 10)) ~ s;
        x /= 10;
    }
    s = ('0' + (x % 10)) ~ s;
    return s;
}

////////////////////////////////////////////////////////
// Scan any type that allMembers works on
void mkBitmapComposite(T)(size_t* p, size_t offset)
{
    version(RTInfoPRINTF) pragma(msg,"mkBitmapComposite " ~ T.stringof);
    static if (is(T P == super))
        static if(P.length > 0)
            mkBitmapComposite!(P[0])(p, offset);

    alias typeof(T.tupleof) TTypes;
    foreach(i, _; TTypes)
    {
        enum cur_offset = T.tupleof[i].offsetof;
        alias Unqual!(TTypes[i]) U;

        version(RTInfoPRINTF) pragma(msg,"  field " ~ T.tupleof[i].stringof ~ " : " ~ U.stringof ~ " @ " ~ totext(cur_offset));
        mkBitmap!U(p, offset + cur_offset);
    }
}

/// set pointer bits for one field
void mkBitmap(T)(size_t* p, size_t offset)
{
    static if (is(T == struct) || 
               is(T == union))
    {
        version(RTInfoPRINTF) pragma(msg,"    mkBitmap composite " ~ T.stringof);

        mkBitmapComposite!T(p, offset);
    }
    else static if (is(T == class) ||
                    is(T == interface))
    {
        version(RTInfoPRINTF) pragma(msg,"      mkBitmap " ~ T.stringof ~ " reference");
        gctemplates_setbit(p, offset);
    }
    else static if (is(T == void))
    {
        version(RTInfoPRINTF) pragma(msg,"      mkBitmap " ~ T.stringof ~ " untyped");
        gctemplates_setbit(p, offset);
    }
    else static if (isBasicType!(T)())
    {
        version(RTInfoPRINTF) pragma(msg,"      mkBitmap " ~ T.stringof ~ " basic type");
    }
    else static if (is(T F == F*) && is(F == function))
    {
        version(RTInfoPRINTF) pragma(msg,"      mkBitmap " ~ T.stringof ~ " function");
    }
    else static if (is(T P == U*, U))
    {
        version(RTInfoPRINTF) pragma(msg,"      mkBitmap " ~ T.stringof ~ " pointer");
        gctemplates_setbit(p, offset);
    }
    else static if (is(T == delegate)) // context pointer of delegate comes first
    {
        version(RTInfoPRINTF) pragma(msg,"      mkBitmap " ~ T.stringof ~ " delegate");
        gctemplates_setbit(p, offset);
    }
    else static if (is(T D == U[], U))
    {
        version(RTInfoPRINTF) pragma(msg,"      mkBitmap " ~ T.stringof ~ " dynamic array of " ~ U.stringof);
        gctemplates_setbit(p, offset + size_t.sizeof); // dynamic array is {length,ptr}
    }
    else static if (is(T A == U[K], U, K))
    {
        version(RTInfoPRINTF) pragma(msg,"      mkBitmap " ~ T.stringof ~ " associative array of " ~ U.stringof ~ ", key " ~ K.stringof);
        gctemplates_setbit(p, offset); // associative array is just a pointer
    }
    else static if(is(T S : U[N], U, size_t N))
    {
        alias Unqual!(U) UU;
        version(RTInfoPRINTF) pragma(msg,"      mkBitmap " ~ T.stringof ~ " static array of " ~ UU.stringof);
        for(size_t i = 0; i < N; i++)
            mkBitmap!UU(p, offset + i * UU.sizeof);
    }
    else static if(is(T E == enum))
    {
        version(RTInfoPRINTF) pragma(msg,"      mkBitmap " ~ T.stringof ~ " enum with base " ~ E.stringof);
        mkBitmap!E(p, offset);
    }
    else static if(is(T E == typedef))
    {
        version(RTInfoPRINTF) pragma(msg,"      mkBitmap " ~ T.stringof ~ " typedef with base " ~ E.stringof);
        mkBitmap!E(p, offset);
    }
    else
    {
        static assert(false, "    mkBitmap does not support " ~ T.stringof);
    }
}

void gctemplates_setbit()(size_t* a, size_t offset)
{
    size_t ptroff = offset/bytesPerPtr;
    version(RTInfoPRINTF) 
        if(offset % bytesPerPtr)
            pragma(msg, "unaligned pointer offset"); // make this an error?
    a[ptroff/ptrPerBitmapWord] |= 1 << (ptroff % ptrPerBitmapWord);
}

