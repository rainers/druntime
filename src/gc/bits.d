/**
 * Contains a bitfield used by the GC.
 *
 * Copyright: Copyright Digital Mars 2005 - 2013.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, David Friedman, Sean Kelly
 */

/*          Copyright Digital Mars 2005 - 2013.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module gc.bits;


import core.bitop;
import core.stdc.string;
import core.stdc.stdlib;


private extern (C) void onOutOfMemoryError();

// version = bitwise;

version (DigitalMars)
{
    version = bitops;
}
else version (GNU)
{
    // use the unoptimized version
}
else version (D_InlineAsm_X86)
{
    version = Asm86;
}

struct GCBits
{
    alias size_t wordtype;

    enum BITS_PER_WORD = (wordtype.sizeof * 8);
    enum BITS_SHIFT = (wordtype.sizeof == 8 ? 6 : 5);
    enum BITS_MASK = (BITS_PER_WORD - 1);
    enum BITS_0 = cast(wordtype)0;
    enum BITS_1 = cast(wordtype)1;
    enum BITS_2 = cast(wordtype)2;

    wordtype*  data = null;
    size_t nwords = 0;    // allocated words in data[] excluding sentinals
    size_t nbits = 0;     // number of bits in data[] excluding sentinals

    void Dtor()
    {
        if (data)
        {
            free(data);
            data = null;
        }
    }

    invariant()
    {
        if (data)
        {
            assert(nwords * data[0].sizeof * 8 >= nbits);
        }
    }

    void alloc(size_t nbits)
    {
        this.nbits = nbits;
        nwords = (nbits + (BITS_PER_WORD - 1)) >> BITS_SHIFT;
        data = cast(typeof(data[0])*)calloc(nwords + 2, data[0].sizeof);
        if (!data)
            onOutOfMemoryError();
    }

    static wordtype test(const(wordtype)* data, size_t i)
    {
        return data[1 + (i >> BITS_SHIFT)] & (BITS_1 << (i & BITS_MASK));
    }

    wordtype test(size_t i)
    in
    {
        assert(i < nbits);
    }
    body
    {
        version (none)
        {
            return core.bitop.bt(data + 1, i);   // this is actually slower! don't use
        }
        else
        {
            //return (cast(bit *)(data + 1))[i];
            return data[1 + (i >> BITS_SHIFT)] & (BITS_1 << (i & BITS_MASK));
        }
    }

    void set(size_t i)
    in
    {
        assert(i < nbits);
    }
    body
    {
        //(cast(bit *)(data + 1))[i] = 1;
        data[1 + (i >> BITS_SHIFT)] |= (BITS_1 << (i & BITS_MASK));
    }

    void clear(size_t i)
    in
    {
        assert(i < nbits);
    }
    body
    {
        //(cast(bit *)(data + 1))[i] = 0;
        data[1 + (i >> BITS_SHIFT)] &= ~(BITS_1 << (i & BITS_MASK));
    }

    wordtype testClear(size_t i)
    {
        version (bitops)
        {
            return core.bitop.btr(data + 1, i);   // this is faster!
        }
        else version (Asm86)
        {
            asm
            {
                naked                   ;
                mov     EAX,data[EAX]   ;
                mov     ECX,i-4[ESP]    ;
                btr     4[EAX],ECX      ;
                sbb     EAX,EAX         ;
                ret     4               ;
            }
        }
        else
        {
            //result = (cast(bit *)(data + 1))[i];
            //(cast(bit *)(data + 1))[i] = 0;

            auto p = &data[1 + (i >> BITS_SHIFT)];
            auto mask = (BITS_1 << (i & BITS_MASK));
            auto result = *p & mask;
            *p &= ~mask;
            return result;
        }
    }

    wordtype testSet(size_t i)
    {
        version (bitops)
        {
            return core.bitop.bts(data + 1, i);   // this is faster!
        }
        else version (Asm86)
        {
            asm
            {
                naked                   ;
                mov     EAX,data[EAX]   ;
                mov     ECX,i-4[ESP]    ;
                bts     4[EAX],ECX      ;
                sbb     EAX,EAX         ;
                ret     4               ;
            }
        }
        else
        {
            //result = (cast(bit *)(data + 1))[i];
            //(cast(bit *)(data + 1))[i] = 0;

            auto p = &data[1 + (i >> BITS_SHIFT)];
            auto  mask = (BITS_1 << (i & BITS_MASK));
            auto result = *p & mask;
            *p |= mask;
            return result;
        }
    }

    mixin template RangeVars()
    {
        size_t firstWord = (target >> BITS_SHIFT) + 1;
        size_t firstOff  = target &  BITS_MASK;
        size_t last      = target + len - 1;
        size_t lastWord  = (last >> BITS_SHIFT) + 1;
        size_t lastOff   = last &  BITS_MASK;
    }

    // target = the biti to start the copy to
    // destlen = the number of bits to copy from source
    void copyRange(size_t target, size_t len, const(wordtype)* source)
    {
        version(bitwise)
        {
            for (size_t i = 0; i < len; i++)
                if(source[(i >> BITS_SHIFT)] & (BITS_1 << (i & BITS_MASK)))
                    set(target+i);
                else
                    clear(target+i);
        }
        else
        {
            if(len == 0)
                return;

            mixin RangeVars!();

            if(firstWord == lastWord)
            {
                wordtype mask = ((BITS_2 << (lastOff - firstOff)) - 1) << firstOff;
                data[firstWord] = (data[firstWord] & ~mask) | ((source[0] << firstOff) & mask);
            }
            else if(firstOff == 0)
            {
                for(size_t w = firstWord; w < lastWord; w++)
                    data[w] = source[w - firstWord];

                wordtype mask = (BITS_2 << lastOff) - 1;
                data[lastWord] = (data[lastWord] & ~mask) | (source[lastWord - firstWord] & mask);
            }
            else
            {
                size_t cntWords = lastWord - firstWord;
                wordtype mask = ~BITS_0 << firstOff;
                data[firstWord] = (data[firstWord] & ~mask) | (source[0] << firstOff);
                for(size_t w = 1; w < cntWords; w++)
                    data[firstWord + w] = (source[w - 1] >> (BITS_PER_WORD - firstOff)) | (source[w] << firstOff);

                wordtype src = (source[cntWords - 1] >> (BITS_PER_WORD - firstOff)) | (source[cntWords] << firstOff);
                mask = (BITS_2 << lastOff) - 1;
                data[lastWord] = (data[lastWord] & ~mask) | (src & mask);
            }
        }
    }

    void copyRangeRepeating(size_t target, size_t destlen, const(wordtype)* source, size_t sourcelen)
    {
        version(bitwise)
        {
            for (size_t i=0; i < destlen; i++)
            {
                bool b;
                size_t j = i % sourcelen;
                b = (source[j >> BITS_SHIFT] & (BITS_1 << (j & BITS_MASK))) != 0;
                if (b) set(target+i);
                else clear(target+i);
            }
        }
        else
        {
            while (destlen > sourcelen)
            {
                copyRange(target, sourcelen, source);
                target += sourcelen;
                destlen -= sourcelen;
            }
            copyRange(target, destlen, source);
        }
    }

    void setRange(size_t target, size_t len)
    {
        version(bitwise)
        {
            for (size_t i = 0; i < len; i++)
                set(target+i);
        }
        else
        {
            if(len == 0)
                return;

            mixin RangeVars!();

            if(firstWord == lastWord)
            {
                wordtype mask = ((BITS_2 << (lastOff - firstOff)) - 1) << firstOff;
                data[firstWord] |= mask;
            }
            else
            {
                data[firstWord] |= ~BITS_0 << firstOff;
                for(size_t w = firstWord + 1; w < lastWord; w++)
                    data[w] = ~0;
                wordtype mask = (BITS_2 << lastOff) - 1;
                data[lastWord] |= mask;
            }
        }
    }

    void clrRange(size_t target, size_t len)
    {
        version(bitwise)
        {
            for (size_t i = 0; i < len; i++)
                clear(target+i);
        }
        else
        {
            if(len == 0)
                return;

            mixin RangeVars!();

            if(firstWord == lastWord)
            {
                wordtype mask = ((BITS_2 << (lastOff - firstOff)) - 1) << firstOff;
                data[firstWord] &= ~mask;
            }
            else
            {
                data[firstWord] &= ~(~BITS_0 << firstOff);
                for(size_t w = firstWord + 1; w < lastWord; w++)
                    data[w] = 0;
                wordtype mask = (BITS_2 << lastOff) - 1;
                data[lastWord] &= ~mask;
            }
        }
    }

    unittest
    {
        GCBits bits;
        bits.alloc(1000);
        auto data = bits.data + 1;

        bits.setRange(0,1);
        assert(data[0] == 1);

        bits.clrRange(0,1);
        assert(data[0] == 0);

        bits.setRange(BITS_PER_WORD-1,1);
        assert(data[0] == BITS_1 << (BITS_PER_WORD-1));

        bits.clrRange(BITS_PER_WORD-1,1);
        assert(data[0] == 0);

        bits.setRange(12,7);
        assert(data[0] == 0x7f000);

        bits.clrRange(14,4);
        assert(data[0] == 0x43000);

        bits.clrRange(0,BITS_PER_WORD);
        assert(data[0] == 0);

        bits.setRange(0,BITS_PER_WORD);
        assert(data[0] == ~0);
        assert(data[1] == 0);

        bits.setRange(BITS_PER_WORD,BITS_PER_WORD);
        assert(data[0] == ~0);
        assert(data[1] == ~0);
        assert(data[2] == 0);
        bits.clrRange(BITS_PER_WORD/2,BITS_PER_WORD);
        assert(data[0] == (BITS_1 << (BITS_PER_WORD/2)) - 1);
        assert(data[1] == ~data[0]);
        assert(data[2] == 0);

        bits.setRange(8*BITS_PER_WORD+1,4*BITS_PER_WORD-2);
        assert(data[8] == ~0 << 1);
        assert(data[9] == ~0);
        assert(data[10] == ~0);
        assert(data[11] == cast(wordtype)~0 >> 1);

        bits.clrRange(9*BITS_PER_WORD+1,2*BITS_PER_WORD);
        assert(data[8] == ~0 << 1);
        assert(data[9] == 1);
        assert(data[10] == 0);
        assert(data[11] == ((cast(wordtype)~0 >> 1) & ~1));
    }

    void zero()
    {
        memset(data + 1, 0, nwords * wordtype.sizeof);
    }

    void copy(GCBits *f)
    in
    {
        assert(nwords == f.nwords);
    }
    body
    {
        memcpy(data + 1, f.data + 1, nwords * wordtype.sizeof);
    }

    wordtype* base()
    in
    {
        assert(data);
    }
    body
    {
        return data + 1;
    }
}

unittest
{
    GCBits b;

    b.alloc(786);
    assert(b.test(123) == 0);
    assert(b.testClear(123) == 0);
    b.set(123);
    assert(b.test(123) != 0);
    assert(b.testClear(123) != 0);
    assert(b.test(123) == 0);

    b.set(785);
    b.set(0);
    assert(b.test(785) != 0);
    assert(b.test(0) != 0);
    b.zero();
    assert(b.test(785) == 0);
    assert(b.test(0) == 0);

    GCBits b2;
    b2.alloc(786);
    b2.set(38);
    b.copy(&b2);
    assert(b.test(38) != 0);
    b2.Dtor();

    b.Dtor();
}
