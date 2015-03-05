import vdc.semantic;
import std.random, std.conv, std.file, std.path;

struct FalsePointers
{
    string s;
    ubyte[40960] data;
}

FalsePointers* ptrs;

void main(string[] argv)
{
    size_t nIter = 20;
    if(argv.length > 2)
        nIter = to!size_t(argv[2]);

    // create some random data as false pointer simulation
    version (RANDOMIZE)
        auto rnd = Random(unpredictableSeed);
    else
        auto rnd = Random(2929088778);

    ptrs = new FalsePointers;
    foreach(ref b; ptrs.data)
        b = cast(ubyte) uniform(0, 255, rnd);

    Project prj = new Project;
    foreach(i; 0..nIter)
    {
        int cnt = 0;
        string path = buildPath("gcbench", "vdparser.extra");
        foreach(name; dirEntries(path, SpanMode.depth))
        {
            if(!globMatch(baseName(name), "*.d"))
                continue;
            prj.addAndParseFile(name);
            cnt++;
        }
        if (cnt != 31)
            assert(false);
    }
}
