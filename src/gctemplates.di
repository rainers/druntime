module gctemplates;

import rumptraits;

static if ((void*).sizeof == 8)
    immutable ulong shiftBy = 3;
else
    immutable ulong shiftBy = 2;
immutable divby = 8* (void*).sizeof;

struct GCInfo
{
    //size of the base portion
    size_t size;
    //base bitmap
    immutable ubyte* bitmap;
    //first bit = is this an array
    size_t flags;
    //size of one array element 
    size_t arrayelementsize;
    //bitmap for one array element
    immutable ubyte* arrayelementbitmap;
}

template allocatedSize(T)
{
    static if (is (T == class))
        enum allocatedSize = __traits(classInstanceSize, T);
    else
        enum allocatedSize = T.sizeof;
}

template bitmapSize(T)
{
    // for 8 bits per byte and the size taken by one pointer. Round up.
    static if (allocatedSize!T > ((allocatedSize!T>>(shiftBy+3))<<(shiftBy+3)))
        enum bitmapSize = ((allocatedSize!T)>>(shiftBy+3)) + 1;
    else
        enum bitmapSize = (allocatedSize!T)>>(shiftBy+3);
}

/*GCInfo RTInfoImpl(T)()
{
    return RTInfoImpl2!T;
}*/

ubyte * RTInfoImpl(T)()
{
    static if (is (T == class) || is(T == struct) || is(T == union))
 //       return GCInfo(allocatedSize!T, compBitmap!T.ptr);
        return cast(ubyte*) &compBitmap!T;
    else static if (isStaticArray!T)
//        return GCInfo(0,cast(immutable ubyte*) 0,0x1,
  //      allocatedSize!(typeof(T[0])),
        return cast (ubyte*) &bitmap!(typeof(T[0]));
    else
//        return GCInfo(
//	allocatedSize!T, 
	return cast (ubyte*) &bitmap!T; //);
}

template bitmap(T)
{
    __gshared bitmap = bitmapImpl!T();
}

template compBitmap(T)
{
    __gshared compBitmap = compBitmapImpl!T();
}

ubyte[bitmapSize!T] compBitmapImpl(T)()
{
    ubyte[bitmapSize!T] A;
    mkBitmapComposite!T(A.ptr, 0);
    return A;
}

ubyte[bitmapSize!T] bitmapImpl(T)()
{
    ubyte[bitmapSize!T] A;
    mkBitmap!T(A.ptr, 0);
    return A;
}

// Scan any type that allMembers works on
void mkBitmapComposite(T)(ubyte* p, size_t offset)
{
    foreach(i, fieldName; (__traits(allMembers, T)))
    {
        static if (__traits(compiles, mixin("(T." ~ fieldName ~").offsetof")))
        {
            size_t cur_offset = mixin("(T." ~ fieldName ~").offsetof");
            mkBitmap!(Unqual!(typeof(mixin("T." ~ fieldName))))(p, offset+cur_offset);
        }
    }
}

void mkBitmap(T)(ubyte* p, size_t offset) if (!hasIndirections!T) {}

void mkBitmap(T)(ubyte* p, size_t offset) if (hasIndirections!T &&
                                            (is(T == struct) ||
                                            is(T == union)))
{
    mkBitmapComposite!T(p, offset);
}

void mkBitmap(T)(ubyte* p, size_t offset) if ((is(T == delegate) ||
                                            is(T : const(void*)) ||
                                            is(T == class) ||
                                            is(T == interface) ||
                                            isAssociativeArray!T) && hasIndirections!T)
{
    setbit(p, offset);
}

void mkBitmap(T)(ubyte* p, size_t offset) if (isDynamicArray!T)
{
setbit(p, offset+(void*).sizeof);
}

void mkBitmap(T)(ubyte* p, size_t offset) if (isStaticArray!T && hasIndirections!T)
{

//mkArrayBitmap!T(p, offset);
   // ubyte[allocatedSize!(T[0])] A;
  //  mkBitmap!(T[0])(A.ptr, 0);
//    for(size_t i = 0; i< T.length; i++)
//      mkBitmap!(T[0])(p, i*T[0].sizeof);
//      copyBitmap(A.ptr, T[0].sizeof, p, offset + i*(T[0].alignof));
    for(size_t i = 0; i< T.length; i++)
        mkBitmap!(Unqual!(typeof(T[0])))(p, offset + i*T[0].sizeof);
}

void setbit(ubyte* a, ulong index)
{
    a[index/divby] =
    a[index/divby] |
    (1<<((index%divby)/8));
}

