module gctemplates;

import rumptraits;

// version = RTInfoPRINTF; // want some compile time debug output?

///////////////////////////////////////////////////////////////////////

immutable bytesPerPtr        = (void*).sizeof;
immutable ptrPerBitmapWord   = 8 * size_t.sizeof;
immutable bytesPerBitmapWord = bytesPerPtr * ptrPerBitmapWord;

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
    immutable RTInfoImpl = RTInfoImpl2!T.ptr;
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
        gctemplates_setbit(p, bytesPerPtr); // mark mutex member
        mkBitmapComposite!(T)(p, 0);
    }
    else
        mkBitmap!(Unqual!T)(p, 0);
}

////////////////////////////////////////////////////////
// Scan any type that allMembers works on
void mkBitmapComposite(T)(size_t* p, size_t offset)
{
    version(RTInfoPRINTF) pragma(msg,"mkBitmapComposite " ~ T.stringof);
    foreach(i, fieldName; (__traits(allMembers, T)))
    {
        // the +1 is a hack to make empty Tuple! made with std/typecons not fail
        static if (__traits(compiles, mixin("((T." ~ fieldName ~").offsetof)+1")))
        {
            size_t cur_offset = mixin("(T." ~ fieldName ~").offsetof");
            alias Unqual!(typeof(mixin("T." ~ fieldName))) U;

            version(RTInfoPRINTF) pragma(msg,"  field " ~ fieldName ~ " : " ~ U.stringof);

            mkBitmap!U(p, offset + cur_offset);
        }
    }
}

//exists for better error messages on template failures
//This way, we get to see what exactly causes a conflict when instatiating templates.
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
    a[ptroff/ptrPerBitmapWord] |= 1 << (ptroff % ptrPerBitmapWord);
}

