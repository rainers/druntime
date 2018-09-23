/**
 * D header file for interaction with C++ std::string.
 *
 * Copyright: Copyright (c) 2018 D Language Foundation
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Guillaume Chatelet
 *            Manu Evans
 * Source:    $(DRUNTIMESRC core/stdcpp/string.d)
 */

module core.stdcpp.string;

///////////////////////////////////////////////////////////////////////////////
// std::string declaration.
//
// Current caveats :
// - won't work with custom allocators
// - missing functions : replace, swap
///////////////////////////////////////////////////////////////////////////////

import core.stdcpp.allocator;
import core.stdc.stddef : wchar_t;

enum DefaultConstruct { value }

/// Constructor argument for default construction
enum Default = DefaultConstruct();

extern(C++, "std"):

///
alias std_string = basic_string!char;
//alias std_u16string = basic_string!wchar; // TODO: can't mangle these yet either...
//alias std_u32string = basic_string!dchar;
//alias std_wstring = basic_string!wchar_t; // TODO: we can't mangle wchar_t properly (yet?)


/**
 * Character traits classes specify character properties and provide specific
 * semantics for certain operations on characters and sequences of characters.
 */
extern(C++, struct) struct char_traits(CharT) {}


/**
* D language counterpart to C++ std::basic_string.
*
* C++ reference: $(LINK2 https://en.cppreference.com/w/cpp/string/basic_string)
*/
extern(C++, class) struct basic_string(T, Traits = char_traits!T, Alloc = allocator!T)
{
extern(D):

    ///
    enum size_type npos = size_type.max;

    ///
    alias size_type = size_t;
    ///
    alias difference_type = ptrdiff_t;
    ///
    alias value_type = T;
    ///
    alias traits_type = Traits;
    ///
    alias allocator_type = Alloc;
    ///
    alias reference = ref value_type;
    ///
    alias const_reference = ref const(value_type);
    ///
    alias pointer = value_type*;
    ///
    alias const_pointer = const(value_type)*;

    ///
    alias as_array this;

    /// MSVC allocates on default initialisation in debug, which can't be modelled by D `struct`
    @disable this();

    ///
    extern(C++) ~this() nothrow @nogc;

    ///
    alias length = size;
    ///
    extern(C++) size_type max_size() const nothrow @trusted @nogc;
    ///
    bool empty() const nothrow @safe @nogc                                  { return size() == 0; }

    ///
    void clear() nothrow @nogc                                              { eos(0); } // TODO: bounds-check
    ///
    void resize(size_type n, T c = T(0)) nothrow @trusted @nogc
    {
        if (n <= size())
            eos(n);
        else
            assert(false); // append(n - size(), c); // write this
    }

//    void reserve(size_type n = 0) @trusted @nogc;
//    void shrink_to_fit();

    ///
    reference front() @safe @nogc                                           { return this[0]; }
    ///
    const_reference front() const @safe @nogc                               { return this[0]; }
    ///
    reference back() @safe @nogc                                            { return this[size()-1]; }
    ///
    const_reference back() const @safe @nogc                                { return this[size()-1]; }

    ///
    const(T)* c_str() const nothrow @safe @nogc                             { return data(); }

    // Modifiers
//    ref basic_string assign(size_type n, T c);
    ///
    ref basic_string opAssign(const(T)[] str)                               { return assign(str); }
    ///
    ref basic_string opAssign(T c)                                          { return assign((&c)[0 .. 1]); }

//    ref basic_string append(size_type n, T c);
    ///
    ref basic_string append(T c)                                            { return append((&c)[0 .. 1]); }
    ///
    ref basic_string opOpAssign(string op : "~")(const(T)[] str)            { return append(str); }
    ///
    ref basic_string opOpAssign(string op : "~")(T c)                       { return append((&c)[0 .. 1]); }

//    ref basic_string insert(size_type pos, ref const(basic_string) str);
//    ref basic_string insert(size_type pos, ref const(basic_string) str, size_type subpos, size_type sublen);
//    ref basic_string insert(size_type pos, const(T)* s) nothrow @nogc                   { assert(s); return insert(pos, s, strlen(s)); }
//    ref basic_string insert(size_type pos, const(T)* s, size_type n) nothrow @trusted @nogc;
//    ref basic_string insert(size_type pos, size_type n, T c);
//    extern(D) ref basic_string insert(size_type pos, const(T)[] s) nothrow @safe @nogc  { insert(pos, &s[0], s.length); return this; }

    ///
    ref basic_string erase(size_type pos = 0) nothrow @nogc // TODO: bounds-check
    {
//        _My_data._Check_offset(pos);
        eos(pos);
        return this;
    }
    ///
    ref basic_string erase(size_type pos, size_type len) nothrow @nogc // TODO: bounds-check
    {
//        _My_data._Check_offset(pos);
        T[] str = as_array();
        size_type new_len = str.length - len;
        this[pos .. new_len] = this[pos + len .. str.length]; // TODO: should be memmove!
        eos(new_len);
        return this;
    }

    // replace
    // swap

    ///
    void push_back(T c) nothrow @trusted @nogc                              { append((&c)[0 .. 1]); }
    ///
    void pop_back() nothrow @nogc                                           { erase(size() - 1); }

    ///
    size_type opDollar(size_t pos)() const nothrow @safe @nogc              { static assert(pos == 0, "std::basic_string is one-dimensional"); return size(); }

    version(CppRuntime_Microsoft)
    {
        ///
        this(DefaultConstruct)                                              { _Alloc_proxy(); _Tidy_init(); }
        ///
        this(const(T)[] ptr) nothrow @nogc                                  { _Alloc_proxy(); _Tidy_init(); assign(ptr); }
        ///
        this(const(T)[] ptr, ref const(allocator_type) al) nothrow @nogc    { _Alloc_proxy(); _AssignAllocator(al); _Tidy_init(); assign(ptr); }
        ///
        this(this)
        {
            _Alloc_proxy();
            if (_Get_data()._IsAllocated())
            {
                T[] _Str = _Get_data()._Mystr;
                _Tidy_init();
                assign(_Str);
            }
        }

        ///
        size_type size() const nothrow @safe @nogc                          { return _Get_data()._Mysize; }
        ///
        size_type capacity() const nothrow @safe @nogc                      { return _Get_data()._Myres; }
        ///
        inout(T)* data() inout @safe @nogc                                  { return _Get_data()._Myptr; }
        ///
        inout(T)[] as_array() inout nothrow @trusted @nogc                  { return _Get_data()._Myptr[0 .. _Get_data()._Mysize]; }
        ///
        ref inout(T) at(size_type i) inout nothrow @trusted @nogc           { if (_Get_data()._Mysize <= i) _Xran(); return _Get_data()._Myptr[i]; }

        ///
        ref basic_string assign(const(T)[] _Str) nothrow @nogc
        {
            size_type _Count = _Str.length;
            auto _My_data = &_Get_data();
            if (_Count <= _My_data._Myres)
            {
                T* _Old_ptr = _My_data._Myptr;
                _My_data._Mysize = _Count;
                _Old_ptr[0 .. _Count] = _Str[]; // TODO: this needs to be a memmove(), does that work here?
                _Old_ptr[_Count] = T(0);
                return this;
            }
            return _Reallocate_for(_Count, (T* _New_ptr, size_type _Count, const(T)* _Ptr) nothrow @nogc {
                _New_ptr[0 .. _Count] = _Ptr[0 .. _Count];
                _New_ptr[_Count] = T(0);
            }, _Str.ptr);
        }

        ///
        ref basic_string append(const(T)[] _Str) nothrow @nogc
        {
            size_type _Count = _Str.length;
            auto _My_data = &_Get_data();
            size_type _Old_size = _My_data._Mysize;
            if (_Count <= _My_data._Myres - _Old_size)
            {
                pointer _Old_ptr = _My_data._Myptr;
                _My_data._Mysize = _Old_size + _Count;
                _Old_ptr[_Old_size .. _Old_size + _Count] = _Str[]; // TODO: this needs to be a memmove(), does that work here?
                _Old_ptr[_Old_size + _Count] = T(0);
                return this;
            }
            return _Reallocate_grow_by(_Count, (T* _New_ptr, const(T)[] _Old_str, const(T)[] _Str) {
                _New_ptr[0 .. _Old_str.length] = _Old_str[];
                _New_ptr[_Old_str.length .. _Old_str.length + _Str.length] = _Str[];
                _New_ptr[_Old_str.length + _Str.length] = T(0);
            }, _Str);
        }

    private:
        import core.stdcpp.xutility : _Xout_of_range, _Xlength_error;

        // Make sure the object files wont link against mismatching objects
        pragma(linkerDirective, "/FAILIFMISMATCH:_ITERATOR_DEBUG_LEVEL=" ~ ('0' + _ITERATOR_DEBUG_LEVEL));

        pragma(inline, true) 
        {
            void eos(size_type offset) nothrow @nogc                        { _Get_data()._Myptr[_Get_data()._Mysize = offset] = T(0); }

            ref _Base.Alloc _Getal() nothrow @safe @nogc                    { return _Base._Mypair._Myval1; }
            ref inout(_Base.ValTy) _Get_data() inout nothrow @safe @nogc    { return _Base._Mypair._Myval2; }
        }

        void _Alloc_proxy() nothrow @nogc
        {
            static if (_ITERATOR_DEBUG_LEVEL > 0)
                _Base._Alloc_proxy();
        }

        void _AssignAllocator(ref const(allocator_type) al) nothrow @nogc
        {
            static if (_Base._Mypair._HasFirst)
                _Getal() = al;
        }

        void _Tidy_init() nothrow @nogc
        {
            auto _My_data = &_Get_data();
            _My_data._Mysize = 0;
            _My_data._Myres = _My_data._BUF_SIZE - 1;
            _My_data._Bx._Buf[0] = T(0);
        }

        size_type _Calculate_growth(size_type _Requested) const nothrow @nogc
        {
            auto _My_data = &_Get_data();
            size_type _Masked = _Requested | _My_data._ALLOC_MASK;
            size_type _Old = _My_data._Myres;
            size_type _Expanded = _Old + _Old / 2;
            return _Masked > _Expanded ? _Masked : _Expanded;
        }

        ref basic_string _Reallocate_for(_ArgTys...)(size_type _New_size, void function(pointer, size_type, _ArgTys) nothrow @nogc _Fn, _ArgTys _Args) nothrow @nogc
        {
            auto _My_data = &_Get_data();
            size_type _Old_capacity = _My_data._Myres;
            size_type _New_capacity = _Calculate_growth(_New_size);
            auto _Al = &_Getal();
            pointer _New_ptr = _Al.allocate(_New_capacity + 1); // throws
            _Base._Orphan_all();
            _My_data._Mysize = _New_size;
            _My_data._Myres = _New_capacity;
            _Fn(_New_ptr, _New_size, _Args);
            if (_My_data._BUF_SIZE <= _Old_capacity)
                _Al.deallocate(_My_data._Bx._Ptr, _Old_capacity + 1);
            _My_data._Bx._Ptr = _New_ptr;
            return this;
        }

        ref basic_string _Reallocate_grow_by(_ArgTys...)(size_type _Size_increase, void function(pointer, const(T)[], _ArgTys) nothrow @nogc _Fn, _ArgTys _Args) nothrow @nogc
        {
            auto _My_data = &_Get_data();
            size_type _Old_size = _My_data._Mysize;
            size_type _New_size = _Old_size + _Size_increase;
            size_type _Old_capacity = _My_data._Myres;
            size_type _New_capacity = _Calculate_growth(_New_size);
            auto _Al = &_Getal();
            pointer _New_ptr = _Al.allocate(_New_capacity + 1); // throws
            _Base._Orphan_all();
            _My_data._Mysize = _New_size;
            _My_data._Myres = _New_capacity;
            if (_My_data._BUF_SIZE <= _Old_capacity)
            {
                pointer _Old_ptr = _My_data._Bx._Ptr;
                _Fn(_New_ptr, _Old_ptr[0 .. _Old_size], _Args);
                _Al.deallocate(_Old_ptr, _Old_capacity + 1);
            }
            else
                _Fn(_New_ptr, _My_data._Bx._Buf[0 .. _Old_size], _Args);
            _My_data._Bx._Ptr = _New_ptr;
            return this;
        }

        static void _Xran() @trusted @nogc { _Xout_of_range("invalid string position"); }
        static void _Xlen() @trusted @nogc { _Xlength_error("string too long"); }

        _String_alloc!(_String_base_types!(T, Alloc)) _Base;
    }
    else
    {
        static assert(false, "C++ runtime not supported");
    }

private:
    // HACK: because no rvalue->ref
    __gshared static immutable allocator_type defaultAlloc;
}


// platform detail
private:
version(CppRuntime_Microsoft)
{
    import core.stdcpp.xutility : _ITERATOR_DEBUG_LEVEL;

    extern (C++) struct _String_base_types(_Elem, _Alloc)
    {
        alias Ty = _Elem;
        alias Alloc = _Alloc;
    }

    extern (C++, class) struct _String_alloc(_Alloc_types)
    {
        import core.stdcpp.xutility : _Compressed_pair;

        alias Ty = _Alloc_types.Ty;
        alias Alloc = _Alloc_types.Alloc;
        alias ValTy = _String_val!Ty;

        void _Orphan_all() nothrow @trusted @nogc;

        static if (_ITERATOR_DEBUG_LEVEL > 0)
        {
            void _Alloc_proxy() nothrow @trusted @nogc;
            void _Free_proxy() nothrow @trusted @nogc;
        }

        _Compressed_pair!(Alloc, ValTy) _Mypair;
    }

    extern (C++, class) struct _String_val(T)
    {
        import core.stdcpp.xutility : _Container_base;
        import core.stdcpp.type_traits : is_empty;

        enum _BUF_SIZE = 16 / T.sizeof < 1 ? 1 : 16 / T.sizeof;
        enum _ALLOC_MASK = T.sizeof <= 1 ? 15 : T.sizeof <= 2 ? 7 : T.sizeof <= 4 ? 3 : T.sizeof <= 8 ? 1 : 0;

        static if (!is_empty!_Container_base.value)
        {
            _Container_base _Base;
        }

        union _Bxty
        {
            T[_BUF_SIZE] _Buf;
            T* _Ptr;
        }

        _Bxty _Bx;
        size_t _Mysize = 0;             // current length of string
        size_t _Myres = _BUF_SIZE - 1;  // current storage reserved for string

    pragma (inline, true):
    extern (D):
        bool _IsAllocated() const @safe @nogc                       { return _BUF_SIZE <= _Myres; }
        @property inout(T)* _Myptr() inout nothrow @trusted @nogc   { return _BUF_SIZE <= _Myres ? _Bx._Ptr : _Bx._Buf.ptr; }
        @property inout(T)[] _Mystr() inout nothrow @trusted @nogc  { return _BUF_SIZE <= _Myres ? _Bx._Ptr[0 .. _Mysize] : _Bx._Buf[0 .. _Mysize]; }
    }
}
