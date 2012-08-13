//private import std.traits; std does not exist yet -- I cannot import anything from there.

//ugly
template Rebindable(T) if (is(T == class) || is(T == interface) || isArray!(T))
{
    static if (!is(T X == const(U), U) && !is(T X == immutable(U), U))
    {
        alias T Rebindable;
    }
    else static if (isArray!(T))
    {
        alias const(ElementType!(T))[] Rebindable;
    }
    else
    {
        struct Rebindable
        {
            private union
            {
                T original;
                U stripped;
            }
            void opAssign(T another) pure nothrow
            {
                stripped = cast(U) another;
            }
            void opAssign(Rebindable another) pure nothrow
            {
                stripped = another.stripped;
            }
            static if (is(T == const U))
            {
                // safely assign immutable to const
                void opAssign(Rebindable!(immutable U) another) pure nothrow
                {
                    stripped = another.stripped;
                }
            }

            this(T initializer) pure nothrow
            {
                opAssign(initializer);
            }

            @property ref T get() pure nothrow
            {
                return original;
            }
            @property ref const(T) get() const pure nothrow
            {
                return original;
            }

            alias get this;
        }
    }
}
template isFunctionPointer(T...)
    if (T.length == 1)
{
    static if (is(T[0] U) || is(typeof(T[0]) U))
    {
        static if (is(U F : F*) && is(F == function))
            enum bool isFunctionPointer = true;
        else
            enum bool isFunctionPointer = false;
    }
    else
        enum bool isFunctionPointer = false;
}

template isStaticArray(T : U[N], U, size_t N)
{
    enum bool isStaticArray = true;
}

template isStaticArray(T)
{
    enum bool isStaticArray = false;
}

template FieldTypeTuple(S)
{
    static if (is(S == struct) || is(S == class) || is(S == union))
        alias typeof(S.tupleof) FieldTypeTuple;
    else
        alias TypeTuple!(S) FieldTypeTuple;
        //static assert(0, "argument is not struct or class");
}
template TypeTuple(TList...)
{
    alias TList TypeTuple;
}
template RepresentationTypeTuple(T)
{
    template Impl(T...)
    {
        static if (T.length == 0)
        {
            alias TypeTuple!() Impl;
        }
        else
        {
            static if (is(T[0] R: Rebindable!R))
            {
                alias Impl!(Impl!R, T[1 .. $]) Impl;
            }
            else static if (is(T[0] == struct) || is(T[0] == union))
            {
    // @@@BUG@@@ this should work
    // alias .RepresentationTypes!(T[0].tupleof)
    // RepresentationTypes;
                alias Impl!(FieldTypeTuple!(T[0]), T[1 .. $]) Impl;
            }
            else static if (is(T[0] U == typedef))
            {
                alias Impl!(FieldTypeTuple!(U), T[1 .. $]) Impl;
            }
            else
            {
                alias TypeTuple!(T[0], Impl!(T[1 .. $])) Impl;
            }
        }
    }

    static if (is(T == struct) || is(T == union) || is(T == class))
    {
        alias Impl!(FieldTypeTuple!T) RepresentationTypeTuple;
    }
    else static if (is(T U == typedef))
    {
        alias RepresentationTypeTuple!U RepresentationTypeTuple;
    }
    else
    {
        alias Impl!T RepresentationTypeTuple;
    }
}

template isPointer(T)
{
    static if (is(T P == U*, U))
    {
        enum bool isPointer = true;
    }
    else
    {
        enum bool isPointer = false;
    }
}

template isDynamicArray(T, U = void)
{
    enum bool isDynamicArray = false;
}

template isDynamicArray(T : U[], U)
{
    enum bool isDynamicArray = !isStaticArray!(T);
}


template isAssociativeArray(T)
{
    enum bool isAssociativeArray = is(AssocArrayTypeOf!T);
}

template AssocArrayTypeOf(T) if (!is(T == enum))
{
       immutable(V [K]) idx(K, V)( immutable(V [K]) );

           inout(V)[K] idy(K, V)( inout(V)[K] );
    shared( V [K]) idy(K, V)( shared( V [K]) );

           inout(V [K]) idz(K, V)( inout(V [K]) );
    shared(inout V [K]) idz(K, V)( shared(inout V [K]) );

           inout(immutable(V)[K]) idw(K, V)( inout(immutable(V)[K]) );
    shared(inout(immutable(V)[K])) idw(K, V)( shared(inout(immutable(V)[K])) );

    static if (is(typeof(idx(defaultInit!T)) X))
    {
        alias X AssocArrayTypeOf;
    }
    else static if (is(typeof(idy(defaultInit!T)) X))
    {
        alias X AssocArrayTypeOf;
    }
    else static if (is(typeof(idz(defaultInit!T)) X))
    {
               inout( V [K]) idzp(K, V)( inout( V [K]) );
               inout( shared(V) [K]) idzp(K, V)( inout( shared(V) [K]) );
               inout( const(V) [K]) idzp(K, V)( inout( const(V) [K]) );
               inout(shared(const V) [K]) idzp(K, V)( inout(shared(const V) [K]) );
               inout( immutable(V) [K]) idzp(K, V)( inout( immutable(V) [K]) );
        shared(inout V [K]) idzp(K, V)( shared(inout V [K]) );
        shared(inout const(V) [K]) idzp(K, V)( shared(inout const(V) [K]) );
        shared(inout immutable(V) [K]) idzp(K, V)( shared(inout immutable(V) [K]) );

        alias typeof(idzp(defaultInit!T)) AssocArrayTypeOf;
    }
    else static if (is(typeof(idw(defaultInit!T)) X))
        alias X AssocArrayTypeOf;
    else
        static assert(0, T.stringof~" is not an associative array type");
}
template isDelegate(T...)
    if(T.length == 1)
{
    enum bool isDelegate = is(T[0] == delegate);
}
template hasIndirections(T)
{
    template Impl(T...)
    {
        static if (!T.length)
        {
            enum Impl = false;
        }
        else static if(isFunctionPointer!(T[0]))
        {
            enum Impl = Impl!(T[1 .. $]);
        }
        else static if(isStaticArray!(T[0]))
        {
            static if (is(T[0] _ : void[N], size_t N))
                enum Impl = true;
            else
                enum Impl = Impl!(T[1 .. $]) ||
                    Impl!(RepresentationTypeTuple!(typeof(T[0].init[0])));
        }
        else
        {
            enum Impl = isPointer!(T[0]) || isDynamicArray!(T[0]) ||
                is (T[0] : const(Object)) || isAssociativeArray!(T[0]) ||
                isDelegate!(T[0]) || is(T[0] == interface)
                || Impl!(T[1 .. $]);
        }
    }

    enum hasIndirections = Impl!(RepresentationTypeTuple!T);
}

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
