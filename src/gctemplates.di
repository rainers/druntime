module gctemplates;

import rumptraits;
//import object;
static if ((void*).sizeof == 8)
    immutable ulong shiftBy = 3;
else
    immutable ulong shiftBy = 2;
immutable divby = 8* (void*).sizeof * size_t.sizeof;


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
    // returns the amount of size_t:s needed to accommodate for the bitmap.
    // for 8 bits per byte, then shiftby for bytes per size_t, then shiftby because
    // we only need a bit for each aligned, pointer-sized target.
    static if (allocatedSize!T > ((allocatedSize!T>>(shiftBy+shiftBy+3))<<(shiftBy+shiftBy+3)))
        enum bitmapSize = ((allocatedSize!T)>>(shiftBy+shiftBy+3)) + 1;
    else
        enum bitmapSize = (allocatedSize!T)>>(shiftBy+shiftBy+3);
}

/*GCInfo RTInfoImpl(T)()
{
    return RTInfoImpl2!T;
}*/

template RTInfoImpl(T)
{
    static if (is (T == class) || is(T == struct) || is(T == union))
       enum RTInfoImpl = (compBitmap!T).ptr;
//GCInfo(allocatedSize!T, compBitmap!T.ptr);
//        return cast(ubyte*), (compBitmap!T).ptr;
    else static if (isStaticArray!T)
       enum RTInfoImpl = null;//(staticArrayBitmap!T).ptr;
// GCInfo(0,cast(immutable ubyte*) 0,0x1, allocatedSize!(typeof(T[0])), (bitmap!(typeof(T[0]))).ptr);
    else
        enum RTInfoImpl = (bitmap!T).ptr;
//GCInfo(
//	allocatedSize!T, 
//	(bitmap!T).ptr);
}

template staticArrayBitmap(T)
{
    immutable staticArrayBitmap = staticArrayBitmapImpl!(T)();
}

template bitmap(T)
{
    immutable bitmap = bitmapImpl!T();
}

template compBitmap(T)
{
    immutable compBitmap = compBitmapImpl!T();
}
// first element is size of the object that the bitmap corresponds to in bytes.
size_t[bitmapSize!T + 1] compBitmapImpl(T)()
{
    size_t[bitmapSize!T + 1] A;
    mkBitmapComposite!T((A.ptr+1),0 );
    A[0] = allocatedSize!T;
    return A;
}

size_t[bitmapSize!T + 1] staticArrayBitmapImpl(T)()
{
    size_t[bitmapSize!T + 1] A;
    for(int i=0; i<T.length; i++)
    {   
        mkBitmap!T((A.ptr+1), i*allocatedSize!(T[0]));
    }    
    A[0] = allocatedSize!T;
    return A;
}

size_t[bitmapSize!T+ 1] bitmapImpl(T)()
{
    size_t[bitmapSize!T + 1] A;
    mkBitmap!T((A.ptr+1), 0);
    A[0] = allocatedSize!T;
    return A;
}

// Scan any type that allMembers works on
void mkBitmapComposite(T)(size_t* p, size_t offset)
{
    foreach(i, fieldName; (__traits(allMembers, T)))
    {
	// the +1 is a hack to make empty Tuple! made with std/typecons not fail
        static if (__traits(compiles, mixin("((T." ~ fieldName ~").offsetof)+1")))
        {

            size_t cur_offset = mixin("(T." ~ fieldName ~").offsetof");
            alias Unqual!(typeof(mixin("T." ~ fieldName))) U;
    
	    bitmapD!U(p, offset+cur_offset);
        }
    }
}

//exists for better error messages on template failures
//This way, we get to see what exactly causes a conflict when instatiating templates.
void bitmapD(T)(size_t* p, size_t offset)
{
    
    // FIXME workaround for http://d.puremagic.com/issues/show_bug.cgi?id=8567
    	    static if ((is (T == struct)) && (isDynamicArray!T))
	    {
		mkBitmapComposite!T(p, offset);
	    }
	    else mkBitmap!T(p, offset);
}

void mkBitmap(T)(size_t* p, size_t offset) if (!hasIndirections!T) {}

void mkBitmap(T)(size_t* p, size_t offset) if (hasIndirections!T &&
                                            (is(T == struct) ||
                                            is(T == union)))
{
    mkBitmapComposite!T(p, offset);
}

void mkBitmap(T)(size_t* p, size_t offset) if ((is(T == delegate) ||
                                            is(T : const(void*)) ||
					    is(T : shared(const(void*))) || //FIXME what is going on here. Comment this line to find a bug
                                            is(T == class) ||
                                            is(T == interface) ||
                                            isAssociativeArray!T) &&
					    hasIndirections!T &&
					    !isDynamicArray!T &&
					    !isStaticArray!T)
{
    gctemplates_setbit(p, offset);
}

void mkBitmap(T)(size_t* p, size_t offset) if (isDynamicArray!T)
{
    gctemplates_setbit(p, offset+(void*).sizeof);
}

void mkBitmap(T)(size_t* p, size_t offset) if (isStaticArray!T && hasIndirections!T)
{
    for(size_t i = 0; i< T.length; i++)
        mkBitmap!(Unqual!(typeof(T[0])))(p, offset + i*T[0].sizeof);
}

void gctemplates_setbit(size_t* a, ulong index)
{
    a[index/divby] =
    a[index/divby] |
    (1<<((index % divby)/(void*).sizeof));
}

