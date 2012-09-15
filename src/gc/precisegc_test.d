// TODO
// - GCBits.setRange,copyRange,etc need optimization
// - Array appender?
// - "shared" in array ?
// - shrinking array should inform GC to clear pointer bits
// - AA: no type info on Nodes
// - new void[]
// - emplace
// BUGS:
// - passing struct larger than 64kB causes bad leave instruction (bugzilla 8658)
// - TypeInfo_Const: next/base (bugzilla 8656)
// - TypeInfo_Const: not transitive for static arrays (bugzilla 8657)
//
// DONE
// - no setPointer on noscan objects
// - verify length in cast from/to void[]

module precisegc_test;

import gctemplates;
import std.stdio;

import gc.gcx;
import gc.gc;

enum BITS_PER_WORD = (size_t.sizeof * 8);
enum BITS_SHIFT = (size_t.sizeof == 8 ? 6 : 5);
enum BITS_MASK = (BITS_PER_WORD - 1);

TypeInfo unqualify(TypeInfo ti)
{
    if(auto tic = cast(TypeInfo_Const)ti)
        while(tic)
        {
            ti = tic.next;
            tic = cast(TypeInfo_Const)ti;
        }
    return ti;
}

bool testBit(const(size_t)* p, size_t biti)
{
    return (p[biti >> BITS_SHIFT] & (1 << (biti & BITS_MASK))) != 0;
}

void testGC(T)(size_t[] expected)
{
    T* p = new T;

    Pool* pool = gc_findPool( cast(void*)p );
    assert(pool);
    size_t biti = cast(void**) p - cast(void**) pool.baseAddr;

    for(size_t i = 0; i < T.sizeof/(void*).sizeof; i++)
    {
        bool e = testBit(expected.ptr, i);
        bool b = pool.is_pointer.test(biti + i) != 0;
        write(b ? 'P' : '.');
        assert(b == e);
    }
}

void __testType(T)(size_t[] expected)
{
    // check compile time info
    enum bits  = (T.sizeof + bytesPerPtr - 1) / bytesPerPtr;
    enum words = (T.sizeof + bytesPerBitmapWord - 1) / bytesPerBitmapWord;
    enum info = RTInfoImpl2!(T);
    writef("%-20s:", T.stringof);
    writef(" CT:%s", info);
    writef(" EXP:%s", expected);
    assert(info[0] == T.sizeof);
    assert(info[1..$] == expected);
    assert(words == expected.length);

    // check run time info
    //writef(" TI:%20s", typeid(T));
    writef(" %20s", typeid(typeid(T)));

    TypeInfo ti = unqualify(typeid(T));

    auto pinfo = cast(immutable(size_t)*) ti.rtInfo();
    if(pinfo is null)
    {
L_testNull:
        write(" RT:null");
        foreach(e; expected)
            assert(e == 0);
    }
    else if(cast(size_t)pinfo == 1)
    {
        //if(auto tip = cast(TypeInfo_Pointer)(typeid(T)))
        //    if(cast(TypeInfo_Function) tip.next)
        //    {
        //        write(" function typed as pointer!");
        //        goto L_xit;
        //    }
        if(auto tia = cast(TypeInfo_StaticArray)ti)
        {
            // no info for static array, repeat value of element
            size_t n = 1;
            while(tia)
            {
                n *= tia.len;
                ti = unqualify(tia.value);
                tia = cast(TypeInfo_StaticArray)ti;
            }
            
            writef(" %s[%d]", ti, n);
            pinfo = cast(immutable(size_t)*) ti.rtInfo();
            if(pinfo is null)
                goto L_testNull;
            if(cast(size_t)pinfo == 1)
                goto L_testOne;

            size_t ebits = (ti.init.length + bytesPerPtr - 1) / bytesPerPtr;
            for(size_t i = 0; i < n; i++)
                for(size_t j = 0; i < ebits; i++)
                    assert(testBit(pinfo + 1, j) == testBit(expected.ptr, i*ebits + j));
        }
        else
        {
        L_testOne:
            write(" RT:1");
            foreach(e; expected[0..$-1])
                assert(e == ~0);
            assert(expected[$-1] == (1 << (bits % ptrPerBitmapWord)) - 1);
        }
    }
    else
    {
        write(" RT:", pinfo[1 .. words+1]);
        assert(pinfo[0] == T.sizeof);
        assert(pinfo[1 .. words+1] == expected[]);
    }
L_xit:
    write(" GC ");
    static if(__traits(compiles, new T))
        testGC!T(expected);
    else
        write("skipped");

    writeln();
}

///////////////////////////////////////
struct S(T, aliasTo = void)
{
    static if(!is(aliasTo == void))
    {
        aliasTo a;
        alias a this;
    }

    size_t x;
    T t;
    void* p;
}

///////////////////////////////////////

void _testType(T)(size_t[] expected)
{
    __testType!(T)(expected);
    __testType!(const(T))(expected);
    __testType!(immutable(T))(expected);
    __testType!(shared(T))(expected);
}

void testType(T)(size_t[] expected)
{
    _testType!(T)(expected);

    // generate bit pattern for S!T
    assert(expected.length == 1);
    size_t[] sexp;
    sexp ~= (expected[0] << (S!T.t.offsetof / bytesPerPtr)) | (1 << (S!T.p.offsetof / bytesPerPtr));
    _testType!(S!T)(sexp);

    // prepend Object
    sexp[0] = (expected[0] << (S!(T, Object).t.offsetof / bytesPerPtr)) | (1 << (S!(T, Object).p.offsetof / bytesPerPtr)) | 1;
    _testType!(S!(T, Object))(sexp);

    // prepend string
    sexp[0] = (expected[0] << (S!(T, string).t.offsetof / bytesPerPtr)) | (1 << (S!(T, string).p.offsetof / bytesPerPtr)) | 2;
    _testType!(S!(T, string))(sexp);
}

///////////////////////////////////////
alias size_t[3] int3;
alias size_t*[3] pint3;
alias string[3] sint3;
alias string[3][2] sint3_2;
alias int delegate() dg;
alias int function() fn;

void testRTInfo()
{
    testType!(bool)         ([ 0b0 ]);
    testType!(ubyte)        ([ 0b0 ]);
    testType!(short)        ([ 0b0 ]);
    testType!(int)          ([ 0b0 ]);
    testType!(long)         ([ 0b00 ]);
    testType!(double)       ([ 0b00 ]);
    testType!(ifloat)       ([ 0b0 ]);
    testType!(cdouble)      ([ 0b0000 ]);
    testType!(dg)           ([ 0b01 ]);
//    testType!(fn)           ([ 0b1 ]); // single function pointer typed as pointer, inconsistent in structs 

    testType!(Object[int])       ([ 0b1 ]);
    testType!(Object[])       ([ 0b10 ]);
    testType!(string)         ([ 0b10 ]);

    testType!(int3)           ([ 0b000 ]);
    testType!(pint3)          ([ 0b111 ]);
    testType!(sint3)          ([ 0b101010 ]);
    testType!(sint3_2)        ([ 0b101010101010 ]);
}

unittest
{
    testRTInfo();
}

void main() {}
