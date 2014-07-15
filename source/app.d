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

int main(string[] args)
{

    auto doc = "
Usage: sift [options] PATTERN
       sift [options] PATTERN [DIR ...]

Arguments:
    PATTERN     pattern to search for
    DIR         directory to start search in.

Options:
    -h --help
    --version              Show version and exit.
    -v                     Reverse the match.
    -i --case-insensitive  Case-insensitive match.
    -m --multi-line        Multiline regex match.
    --no-color             no color output
    --name-only            Show only filename of matches
    --depth-first          Depth first search

File type options:
    --d         D files
    --c         C/C++ files
    --c++       C/C++ files
    --py        Python files
    ";

    auto arguments = docopt.docopt(doc, args[1..$], true, "0.1.0");

    auto spanMode = SpanMode.breadth;
    if (arguments["--depth-first"].isTrue()) {
        spanMode = SpanMode.depth;
    }

    auto flags = "";
    if (arguments["--case-insensitive"].isTrue()) {
        flags ~= "i";
    }
    if (arguments["--multi-line"].isTrue()) {
        flags ~= "m";
    }
    auto matcher = regex(arguments["PATTERN"].toString(), flags);
    if (arguments["DIR"].isEmpty()) {
        arguments["DIR"].add(".");
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

    foreach(dir; arguments["DIR"].asList()) {
        auto dirName = buildNormalizedPath(dir);        
        auto files = dirEntries(dirName, spanMode);
        foreach(item; files) {
            if (!item.isFile()) {
                continue;
            }
            if (extMatch(item, defaultExts)) {
                bool first = true;
                auto file = File(item);
                auto range = file.byLine();
                auto lcount = 0;
                foreach(line; range) {
                    lcount += 1;
                    auto captures = matchFirst(line, matcher);
                    bool printMatch = !captures.empty() && arguments["-v"].isFalse();
                    bool printNoMatch = captures.empty() && arguments["-v"].isTrue();
                    if (printMatch || printNoMatch) {
                        if (first) {
                            if (arguments["--name-only"].isTrue()) {
                                writeln(item);
                            } else {
                                writeln(format("\n%s", item));
                            }
                            first = false;
                        }
                        if (arguments["--name-only"].isFalse()) {
                            writeln(format("%d: %s", lcount, line));
                        }
                    }
                }
            }
        }
    }

    return 0;
}
