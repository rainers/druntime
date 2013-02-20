module genexp;

import std.stdio;
static import std.file;
import std.string;
import std.utf;
import std.conv;

import core.demangle;

void main(string[] argv)
{
    foreach(f; argv[1..$])
    {
        ubyte[] txt = cast(ubyte[])std.file.read(f);
        ubyte[] newl = ['\n'];
        ubyte[][] lines = split(txt, newl);
        foreach(lnum, line; lines)
        {
            ubyte[] space = [' '];
            ubyte[][] tokens = split(line, space);
            if(tokens.length == 2) try
            {
                uint pos = 0;
                string s = decodeDmdString(cast(char[])tokens[0], pos);
                if(s.startsWith('_'))
                   s = s[1..$];
                string sz = cast(string)(tokens[1]);
                int size = parse!int(sz);
                writeln("extern(C) extern __gshared int ", s, "_E;");
                write("extern(C) __gshared ubyte[", size, "] ", s, " = [");
                // generate a sequence that always points to the magic (using UTF8 to encode the offset)
                uint diff = size;
                while(diff > 0)
                {
                    char buf[4];
                    uint len = std.utf.encode(buf, diff);
                    for(uint p = 0; p < len; p++, diff--)
                        write(diff == size ? " 0x" : ", 0x", to!string(cast(ubyte) buf[p], 16));
                }
                writeln(" ];");
                writeln("extern(C) __gshared int ", s, "_magic = 0xBAFAFADE;");
                writeln("extern(C) __gshared int ", s, "_size = ", size, ";");
                writeln("extern(C) __gshared int* ", s, "_ptr = &", s, "_E;");
                writeln;
            }
            catch(Exception e)
            {
                stderr.writeln(f, "(", lnum + 1, "):", e.msg);
            }
        }
    }
}
