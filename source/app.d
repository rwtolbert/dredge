//  grep-like tool written in D.
//
//  Copyright (c) 2014 Bob Tolbert, bob@tolbert.org
//  Licensed under terms of MIT license (see LICENSE-MIT)
//
//  https://github.com/rwtolbert/sift
//

import std.file;
import std.path;
import std.stdio;
import std.string;
import std.algorithm;
import std.regex;
import std.utf;
import std.stream;
import std.cstream;
import std.getopt;

import docopt;

public bool extMatch(const DirEntry de, const int[string] exts)
{
    return exts.get(extension(de.name), 0) == 1;
}

public bool nameMatch(const DirEntry de, const int[string] names)
{
    return names.get(baseName(de.name), 0) == 1;
}

void addExts(ref int[string] exts, const string input, int value=1)
{
    foreach(e; split(input, " "))
    {
        exts[e] = value;
    }
}

void addNames(ref int[string] names, const string input, int value=1)
{
    foreach(n; split(input, " "))
    {
        names[n] = value;
    }
}

void searchOneFileStream(T)(InputStream inp, const string filename,
                            Regex!T matcher, bool reverse, bool name_only,
                            bool no_filename)
{
    bool first = true;
    foreach(ulong lcount, T[] line; inp)
    {
        auto captures = matchFirst(line, matcher);
        bool printMatch = !captures.empty() && !reverse;
        bool printNoMatch = captures.empty() && reverse;
        if (printMatch || printNoMatch)
        {
            if (first)
            {
                if (name_only)
                {
                    writeln(filename);
                }
                else
                {
                    if (!no_filename)
                    {
                        writeln(format("\n%s", filename));
                    }
                }
                first = false;
            }
            if (!name_only)
            {
                writeln(format("%d:%s", lcount, line));
            }
        }
    }
}

template GenRule(string ftype, string inputs, string names)
{
    const char[] GenRule = format("""
    if (no_%s)
    {
        addExts(defaultExts, \"%s\", 0);
        addNames(defaultNames, \"%s\", 0);
    }
    else
    {
        addExts(defaultExts, \"%s\", 1);
        addNames(defaultNames, \"%s\", 1);
        if (use_%s)
        {
            addExts(userExts, \"%s\", 1);
            addNames(userNames, \"%s\", 1);
        }
    }
""", ftype, inputs, names, inputs, names, ftype, inputs, names);
}

int main(string[] args)
{
    auto usage = "
Usage: sift [options] PATTERN [FILES ...]
       sift -f [options] [FILES ...]
       sift --help
       sift --help-types
       sift --version
    ";

    auto doc = "
Arguments:
    PATTERN     pattern to search for
    FILES       files or directories to search. [default: .]

Search options:
    -v                     Reverse the match.
    -Q --literal           Quote all meta-characters.
    -i --case-insensitive  Case-insensitive match.
    -w --word-regex        Match whole words only.

Output options:
    -H --with-filename     Include filename before match.
    -h --no-filename       No filename before match.
    --no-color             no color output
    -g, --name-only        Show only filename of matches
    -s                     Suppress failure on missing or unreadable file.

Base options:
    --help
    --help-types           Show help on file type flags.
    --version              Show version and exit.

File find options:
    -f --find-files        Only print files selected.
    --sort-files           Sort the files found.

File inclusion options:
    -n, --no-recurse       No descending into subdirectories
    --follow               Follow symlinks.  Default is off.

    ";

    auto typeOptions = "
File type options:
    --c           C files        [.c .h]
    --cpp         C++ files      [.cpp .cc .cxx .c++ .hpp .tpp .hh .h .hxx]
    --clojure     Clojure files  [.clj]
    --cmake       CMake files    [CMakeLists.txt .cmake]
    --coffee      Coffeescript   [.coffee]
    --csharp      C# files       [.cs]
    --d           D files        [.d]
    --fsharp      F# files       [.fs .fsx]
    --go          Go files       [.go]
    --hy          Hy files       [.hy]
    --js          Javascript     [.js]
    --json        JSON           [.json]
    --powershell  Powershell     [.ps1 .psm1 .psd1 .psc1]
    --py          Python files   [.py]
    --ruby        Ruby files     [.rb .rhtml .rjs .rxml .erb .rake .spec Rakefile]
    --swig        SWIG files     [.i]
    ";

    string[dchar] metaTable = ['[': "\\[",
                               '{': "\\{",
                               '|': "\\|",
                               '*': "\\*",
                               '+': "\\+",
                               '?': "\\?",
                               '(': "\\(",
                               ')': "\\)",
                               '^': "\\^",
                               '$': "\\$",
                               '\\': "\\\\",
                               '.': "\\."];

    bool help = false;
    bool help_types = false;

    bool reverse = false;
    bool literal = false;
    bool case_insensitive = false;
    bool word_regex = false;
    bool no_recurse = false;
    bool follow = false;

    bool name_only = false;
    bool with_filename = true;
    bool no_filename = false;

    bool silent = false;

    bool find_files = false;
    bool sort_files = false;

    bool use_c = false;
    bool no_c = false;

    bool use_cpp = false;
    bool no_cpp = false;

    bool use_cmake = false;
    bool no_cmake = false;

    bool use_coffee = false;
    bool no_coffee = false;

    bool use_csharp = false;
    bool no_csharp = false;

    bool use_d = false;
    bool no_d = false;

    bool use_fsharp = false;
    bool no_fsharp = false;

    bool use_go = false;
    bool no_go = false;

    bool use_hy = false;
    bool no_hy = false;

    bool use_js = false;
    bool no_js = false;

    bool use_json = false;
    bool no_json = false;

    bool use_powershell = false;
    bool no_powershell = false;

    bool use_py = false;
    bool no_py = false;

    bool use_ruby = false;
    bool no_ruby = false;

    bool use_swig = false;
    bool no_swig = false;

    getopt(args,
           std.getopt.config.passThrough,
           "help", &help,
           "help-types", &help_types,
           "reverse|v", &reverse,
           "literal|Q", &literal,
           "case-insensitive|i", &case_insensitive,
           "word-regex|w", &word_regex,
           "no-recurse|n", &no_recurse,
           "follow", &follow,
           "name-only|g", &name_only,
           "with-filename|H", &with_filename,
           "no-filename|h", &no_filename,
           "silent|s", &silent,
           "find-files|f", &find_files,
           "sort-files|g", &sort_files,
           "c", &use_c, "no-c", &no_c,
           "cpp", &use_cpp, "no-cpp", &no_cpp,
           "cmake", &use_cmake, "no-cmake", &no_cmake,
           "coffee", &use_coffee, "no-coffee", &no_coffee,
           "csharp", &use_csharp, "no-csharp", &no_csharp,
           "d", &use_d, "no-d", &no_d,
           "fsharp", &use_fsharp, "no-fsharp", &no_fsharp,
           "go", &use_go, "no-go", &no_go,
           "hy", &use_hy, "no-hy", &no_hy,
           "js", &use_js, "no-js", &no_js,
           "json", &use_json, "no-json", &no_json,
           "powershell", &use_powershell, "no-powershell", &no_powershell,
           "py", &use_py, "no-py", &no_py,
           "ruby", &use_ruby, "no-ruby", &no_ruby,
           "swig", &use_swig, "no-swig", &no_swig
        );

    if (help)
    {
        write(usage);
        writeln(doc);
        return 0;
    }

    if (help_types)
    {
        write(usage);
        writeln(typeOptions);
        return 0;
    }

    auto spanMode = SpanMode.breadth;
    if (no_recurse)
    {
        spanMode = SpanMode.shallow;
    }

    auto flags = "";
    if (case_insensitive)
    {
        flags ~= "i";
    }

    if (args.length == 1 && !find_files)
    {
        writeln(usage);
        return 1;
    }

    string pattern = "";
    string[] files;
    if (find_files)
    {
        if (args.length == 1)
        {
            files = ["."];
        }
        else
        {
            files = args[1..$];
        }
    }
    else
    {
        if (args.length == 2)
        {
            pattern = args[1];
            files = ["."];
        }
        else if (args.length > 2)
        {
            pattern = args[1];
            files = args[2..$];
        }
        else
        {
            writeln(usage);
            return 1;
        }
    }

    int[string] defaultExts;
    int[string] defaultNames;
    int[string] userExts;
    int[string] userNames;

    mixin(GenRule!("c", ".c .h", ""));
    mixin(GenRule!("cpp", ".cpp .cc .cxx .c++ .hpp .tpp .hh .h .hxx", ""));
    mixin(GenRule!("cmake", ".cmake", "CMakeLists.txt"));
    mixin(GenRule!("coffee", ".coffee", ""));
    mixin(GenRule!("csharp", ".cs", ""));
    mixin(GenRule!("d", ".d", ""));
    mixin(GenRule!("fsharp", ".fs .fsx", ""));
    mixin(GenRule!("go", ".go", ""));
    mixin(GenRule!("hy", ".hy", ""));
    mixin(GenRule!("js", ".js", ""));
    mixin(GenRule!("json", ".json", ""));
    mixin(GenRule!("powershell", ".ps1 .psd1 .psm1 .psc1", ""));
    mixin(GenRule!("py", ".py", ""));
    mixin(GenRule!("ruby", ".rb .rhtml .rjs .rxml .erb .rake .spec", "Rakefile"));
    mixin(GenRule!("swig", ".i", ""));

    if (userExts.length > 0 || userNames.length > 0)
    {
        defaultExts = userExts;
        defaultNames = userNames;
    }

    try
    {
        if (files.length == 1 && files[0] == "-")
        {
            no_filename = true;
        }
        else if (files.length == 1 && files[0].isFile && !with_filename)
        {
            no_filename = true;
        }
        else if (with_filename)
        {
            no_filename = false;
        }
    }
    catch(std.file.FileException e)
    {
        if (silent)
        {
            writeln("Unknown file: ", files[0]);
        }
        return -1;
    }

    uint[string] ignoreDirs = [".git":1, ".hg":1, ".svn":1, ".dub":1, "CVS":1, ".DS_Store":1];
    string[] fileList;
    foreach(item; files)
    {
        try
        {
            if (item == "-" || item.isFile)
            {
                fileList ~= item;
            }
            else if (item.isDir)
            {
                auto thisDir = buildNormalizedPath(item);
                auto dirFiles = dirEntries(thisDir, spanMode, follow);
                foreach(fileName; dirFiles)
                {
                    if (baseName(dirName(fileName)) in ignoreDirs)
                    {
                        continue;
                    }
                    if (fileName.isFile() && (extMatch(fileName, defaultExts) ||
                                              nameMatch(fileName, defaultNames)))
                    {
                        fileList ~= fileName;
                    }
                }
            }
        }
        catch(std.file.FileException e)
        {
            if (silent)
            {
                writeln("Unknown file: ", item);
            }
        }
    }

    //writeln(fileList);

    if (sort_files)
    {
        std.algorithm.sort(fileList);
    }

    if (find_files)
    {
        foreach(filename; fileList)
        {
            writeln(filename);
        }
        return 0;
    }

    if (literal)
    {
        pattern = translate(pattern, metaTable);
    }
    if (word_regex)
    {
        pattern = format("\\b%s\\b", pattern);
    }
    auto matcher = regex(pattern, flags);
    auto wmatcher = regex(std.utf.toUTF16(pattern), flags);

    foreach(filename; fileList)
    {
        BufferedStream fstream;
        EndianStream inp;
        int bom;

        if (filename == "-")
        {
            inp = new EndianStream(std.cstream.din);
            bom = -1;
        }
        else
        {
            fstream = new BufferedFile(filename);
            inp = new EndianStream(fstream);
            bom = inp.readBOM();
        }

        switch(bom)
        {
            case BOM.UTF16LE, BOM.UTF16BE:
                searchOneFileStream!wchar(inp, filename, wmatcher,
                                          reverse, name_only, no_filename);
                break;
            case BOM.UTF8:
            default:
                searchOneFileStream!char(inp, filename, matcher,
                                         reverse, name_only, no_filename);
                break;
        }

        inp.close();
        if (fstream)
        {
            fstream.close();
        }
    }

    return 0;
}
