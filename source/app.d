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

import docopt;

public bool extMatch(const DirEntry de, const int[string] exts)
{
    return exts.get(extension(de.name), 0) == 1;
}

public bool nameMatch(const DirEntry de, const int[string] names)
{
    return names.get(baseName(de.name), 0) == 1;
}

void addDFiles(ref int[string] exts) {
    exts[".d"] = 1;
}

void addCFiles(ref int[string] exts) {
    exts[".c"] = 1;
    exts[".h"] = 1;
}

void addCPPFiles(ref int[string] exts) {
    exts[".h"] = 1;
    exts[".hh"] = 1;
    exts[".cc"] = 1;
    exts[".cpp"] = 1;
    exts[".cxx"] = 1;
    exts[".c++"] = 1;
    exts[".hpp"] = 1;
    exts[".hxx"] = 1;
    exts[".tpp"] = 1;
}

void addCSharpFiles(ref int[string] exts) {
    exts[".cs"] = 1;
}

void addPyFiles(ref int[string] exts) {
    exts[".py"] = 1;
}

void addHyFiles(ref int[string] exts) {
    exts[".hy"] = 1;
}

void addCMakeFiles(ref int[string] exts, ref int[string] names) {
    exts[".cmake"] = 1;
    names["CMakeLists.txt"] = 1;
}

void getDefaultExtensions(ref int[string] exts, ref int[string] names) {
    addDFiles(exts);
    addCFiles(exts);
    addCMakeFiles(exts, names);
    addCPPFiles(exts);
    addCSharpFiles(exts);
    addPyFiles(exts);
}

void searchOneFileStream(T)(InputStream inp, const string filename,
                            Regex!T matcher, const docopt.ArgValue[string] arguments)
{
    bool first = true;
    bool reverse = arguments["-v"].isTrue();
    foreach(ulong lcount, T[] line; inp)
    {
        auto captures = matchFirst(line, matcher);
        bool printMatch = !captures.empty() && !reverse;
        bool printNoMatch = captures.empty() && reverse;
        if (printMatch || printNoMatch) {
            if (first) {
                if (arguments["--name-only"].isTrue()) {
                    writeln(filename);
                } else {
                    if (arguments["--no-filename"].isFalse()) {
                        writeln(format("\n%s", filename));
                    }
                }
                first = false;
            }
            if (arguments["--name-only"].isFalse()) {
                writeln(format("%d:%s", lcount, line));
            }
        }
    }
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

Output options:
    -H --with-filename     Include filename before match.
    -h --no-filename       No filename before match.       
    --no-color             no color output
    -g, --name-only        Show only filename of matches

Base options:
    --help
    --help-types           Show help on file type flags.
    --version              Show version and exit.

File find options:
    -f                     Only print files selected.
    --sort-files           Sort the files found.

File inclusion options:
    -n, --no-recurse       No descending into subdirectories
    --follow               Follow symlinks.  Default is off.

    ";

    auto typeOptions = "
File type options:
    --d         D files        [.d]
    --c         C files        [.c .h]
    --cpp       C++ files      [.cpp .cc .cxx .c++ .hpp .tpp .hh .h .hxx]
    --clojure   Clojure files  [.clj]
    --cmake     CMake files    [CMakeLists.txt .cmake]
    --csharp    C# files       [.cs]
    --hy        Hy files       [.hy]
    --py        Python files   [.py]
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

    auto miniDoc = usage ~ doc;
    auto arguments = docopt.docopt(miniDoc, args[1..$], true, "0.1.0");

    if (arguments["--help-types"].isTrue()) {
        write(usage);
        writeln(typeOptions);
        return 0;
    }

    auto fullDoc = miniDoc ~ typeOptions;
    arguments = docopt.docopt(fullDoc, args[1..$], true);

    //writeln(arguments);

    auto spanMode = SpanMode.breadth;
    if (arguments["--no-recurse"].isTrue()) {
        spanMode = SpanMode.shallow;
    }
    bool follow = arguments["--follow"].isTrue();

    auto flags = "";
    if (arguments["--case-insensitive"].isTrue()) {
        flags ~= "i";
    }

    if (arguments["FILES"].isEmpty()) {
        arguments["FILES"].add(".");
    }

    int[string] defaultExts;
    int[string] defaultNames;
    getDefaultExtensions(defaultExts, defaultNames);

    int[string] userExts;
    int[string] userNames;
    if (arguments["--d"].isTrue()) {
        addDFiles(userExts);
    }
    if (arguments["--c"].isTrue()) {
        addCFiles(userExts);
    }
    if (arguments["--cpp"].isTrue()) {
        addCFiles(userExts);
        addCPPFiles(userExts);
    }
    if (arguments["--cmake"].isTrue()) {
        addCMakeFiles(userExts, userNames);
    }
    if (arguments["--csharp"].isTrue()) {
        addCSharpFiles(userExts);
    }
    if (arguments["--py"].isTrue()) {
        addPyFiles(userExts);
    }
    if (arguments["--hy"].isTrue()) {
        addHyFiles(userExts);
    }
    if (userExts.length > 0 || userNames.length > 0) {
        defaultExts = userExts;
        defaultNames = userNames;
    }

//    writeln(arguments["FILES"]);

    auto FILES = arguments["FILES"].asList();
    try {
        if (FILES.length == 1 && FILES[0] == "-") {
            arguments["--no-filename"] = new docopt.ArgValue(true);
        } else if (FILES.length == 1 && FILES[0].isFile && arguments["--with-filename"].isFalse()) {
            arguments["--no-filename"] = new docopt.ArgValue(true);
        } else if (arguments["--with-filename"].isTrue()) {
            arguments["--no-filename"] = new docopt.ArgValue(false);
        }
    } catch(std.file.FileException e) {
        writeln("Unknown file: ", FILES[0]);
        return -1;
    }

    string [] fileList;
    foreach(item; FILES) {
        try {
            if (item == "-") {
                fileList ~= item;
            } else if (item.isFile) {
                fileList ~= item;
            } else if (item.isDir) {
                auto dirName = buildNormalizedPath(item);
                auto files = dirEntries(dirName, spanMode, follow);
                foreach(fileName; files) {
                    if (fileName.isFile() && (extMatch(fileName, defaultExts) ||
                                              nameMatch(fileName, defaultNames))) {
                        fileList ~= fileName;
                    }
                }
            }
        } catch(std.file.FileException e) {
            writeln("Unknown file: ", item);
            return -1;
        }
    }

    if (arguments["--sort-files"].isTrue) {
        std.algorithm.sort(fileList);
    }

    if (arguments["-f"].isTrue) {
        foreach(filename; fileList) {
            writeln(filename);
        }
        return 0;
    }

    auto pattern = arguments["PATTERN"].toString();
    if (arguments["--literal"].isTrue()) {
        pattern = translate(pattern, metaTable);
    }
    auto matcher = regex(pattern, flags);
    auto wmatcher = regex(std.utf.toUTF16(pattern), flags);

    foreach(filename; fileList) {
        BufferedStream fstream;
        EndianStream inp;
        int bom;

        if (filename == "-") {
            inp = new EndianStream(std.cstream.din);
            bom = -1;
        } else {
            fstream = new BufferedFile(filename);
            inp = new EndianStream(fstream);
            bom = inp.readBOM();
        }

        switch(bom) {
            case BOM.UTF16LE, BOM.UTF16BE:
                searchOneFileStream!wchar(inp, filename, wmatcher, arguments);
                break;
            case BOM.UTF8:
            default:
                searchOneFileStream!char(inp, filename, matcher, arguments);
                break;
        }

        inp.close();
        if (fstream) {
            fstream.close();
        }
    }

    return 0;
}
