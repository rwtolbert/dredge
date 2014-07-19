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

import docopt;

public bool extMatch(DirEntry de, int[string] exts)
{
    return exts.get(extension(de.name), 0) == 1;
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
    exts[".cc"] = 1;
    exts[".cpp"] = 1;
    exts[".cxx"] = 1;
    exts[".c++"] = 1;
    exts[".hpp"] = 1;
}

void addPyFiles(ref int[string] exts) {
    exts[".py"] = 1;
}

int[string] getDefaultExtensions() {
    int[string] exts;
    addDFiles(exts);
    addCFiles(exts);
    addCPPFiles(exts);
    addPyFiles(exts);
    return exts;
}

int detectBOM(string filename)
{
    BufferedStream fstream = new BufferedFile(filename);
    EndianStream file = new EndianStream(fstream);
    int bom = file.readBOM();
    file.close();
    fstream.close();
    return bom;
}

void searchOneFileStream(T)(string filename, Regex!T matcher, docopt.ArgValue[string] arguments)
{
    bool first = true;
    BufferedStream fstream = new BufferedFile(filename);
    EndianStream file = new EndianStream(fstream);
    ulong lcount = 0;
    foreach(T[] line; file)
    {
        lcount += 1;
        auto captures = matchFirst(line, matcher);
        bool printMatch = !captures.empty() && arguments["-v"].isFalse();
        bool printNoMatch = captures.empty() && arguments["-v"].isTrue();
        if (printMatch || printNoMatch) {
            if (first) {
                if (arguments["--name-only"].isTrue()) {
                    writeln(filename);
                } else {
                    writeln(format("\n%s", filename));
                }
                first = false;
            }
            if (arguments["--name-only"].isFalse()) {
                writeln(format("%d: %s", lcount, line));
            }
        }
    }
    file.close();
    fstream.close();
}

int main(string[] args)
{

    auto doc = "
Usage: sift [options] PATTERN [FILES ...]

Arguments:
    PATTERN     pattern to search for
    FILES       files or directories to search. [default: .]

Options:
    -h --help
    -v                     Reverse the match.
    -Q --literal           Quote all meta-characters.
    -i --case-insensitive  Case-insensitive match.
    --no-color             no color output
    --name-only            Show only filename of matches
    --depth-first          Depth first search
    --version              Show version and exit.

File type options:
    --d         D files
    --c         C/C++ files
    --c++       C/C++ files
    --py        Python files
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

    auto arguments = docopt.docopt(doc, args[1..$], true, "0.1.0");

    auto spanMode = SpanMode.breadth;
    if (arguments["--depth-first"].isTrue()) {
        spanMode = SpanMode.depth;
    }

    auto flags = "";
    if (arguments["--case-insensitive"].isTrue()) {
        flags ~= "i";
    }

    auto pattern = arguments["PATTERN"].toString();
    if (arguments["--literal"].isTrue()) {
        pattern = translate(pattern, metaTable);
    }
    auto matcher = regex(pattern, flags);
    auto wmatcher = regex(std.utf.toUTF16(pattern), flags);
    auto dmatcher = regex(std.utf.toUTF32(pattern), flags);

    if (arguments["FILES"].isEmpty()) {
        arguments["FILES"].add(".");
    }

    int[string] defaultExts = getDefaultExtensions();
    int[string] userExts;
    if (arguments["--d"].isTrue()) {
        addDFiles(userExts);
    }
    if (arguments["--c"].isTrue()) {
        addCFiles(userExts);
    }
    if (arguments["--c++"].isTrue()) {
        addCFiles(userExts);
        addCPPFiles(userExts);
    }
    if (arguments["--py"].isTrue()) {
        addPyFiles(userExts);
    }
    if (userExts.length > 0) {
        defaultExts = userExts;
    }

//    writeln(arguments["FILES"]);

    string [] fileList;
    foreach(item; arguments["FILES"].asList()) {
        if (item.isFile) {
            fileList ~= item;
        } else if (item.isDir) {
            auto dirName = buildNormalizedPath(item);
            auto files = dirEntries(dirName, spanMode);
            foreach(fileName; files) {
                if (fileName.isFile() && extMatch(fileName, defaultExts)) {
                    fileList ~= fileName;
                }
            }
        }
    }

    foreach(file; fileList) {
        auto bom = detectBOM(file);
        switch(bom) {
            case BOM.UTF8:
                writeln("utf-8 ", file);
                searchOneFileStream!char(file, matcher, arguments);
                break;
            case BOM.UTF16LE, BOM.UTF16BE:
                searchOneFileStream!wchar(file, wmatcher, arguments);
                break;
            // case BOM.UTF32LE, BOM.UTF32BE:
            //     writeln("utf-32 ", file);
            //     searchOneFileStream!dchar(file, dmatcher, arguments);
            //     break;
            default:
                searchOneFileStream!char(file, matcher, arguments);
                break;
        }
    }

    return 0;
}
