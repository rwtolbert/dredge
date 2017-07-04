import std.stdio;
import std.stream;
import std.process;

int main(string[] args)        
{                              
    return 0;
}

string exe = "..\\dg.exe ";
string dataDir = "./data";

struct TestCase
{
    string name;
    string args;
    uint status;
    this(const string n, const string a, uint s)
    {
        name = n;
        args = a;
        status = s;
    }
}

string genTestOutputName(string testName)
{
    import std.path;

    auto baseName = testName ~ ".output";
    auto fname = buildNormalizedPath(dataDir, baseName);

    return fname;
}

bool createOutput(string testName, string output)
{
    import std.stream;

    auto fname = genTestOutputName(testName);
    writefln("Writing %s", fname);

    auto ofp = new BufferedFile(fname, FileMode.Out);
    ofp.write(output);
    ofp.close();

    return true;
}

bool runTest(const TestCase test, bool generate)
{
    writeln("=========================================================");
    writefln("Running: %s", test.name);

    auto cmd = exe ~ test.args;
    writeln(cmd);

    auto res = executeShell(cmd);

    if (generate)
    {
        createOutput(test.name, res.output);
    }
    else
    {
        assert(res.status == test.status);
        
        writeln("Success");
        writeln("=========================================================");
    }

    return true;
}

unittest {

    import std.c.stdlib;

    bool generate = false;
    auto GEN = getenv("GENERATE");
    if (GEN != null)
    {
        generate = true;
        writeln("generating new output");
    }

    TestCase[] tests = [
        TestCase("empty", "", -1),
        TestCase("help", "--help", 0),
        TestCase("help-types", "--help-types", 0),
        TestCase("version", "--version", 0)
        ];

    foreach(testcase; tests)
    {
        runTest(testcase, generate);
    }

}
