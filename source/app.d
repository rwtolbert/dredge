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

import colorize;

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
                            bool no_filename, bool showColor,
                            const bg matchColor=bg.yellow,
                            const fg lineColor=fg.yellow,
                            const fg fileColor=fg.green)
{
    bool first = true;

    string cfilename = filename;
    if (showColor)
    {
        cfilename = color(cfilename, fileColor, bg.init, mode.bold);
    }

    foreach(ulong lcount, T[] line; inp)
    {
        auto captures = matchAll(line, matcher);
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
                        cwritefln("\n%s", cfilename);
                    }
                }
                first = false;
            }
            if (!name_only)
            {
                string lineNo = format("%d", lcount);
                if (showColor)
                {
                    line = replaceAll(line, matcher, color("$0", fg.black, matchColor, mode.bold));
                    lineNo = color(lineNo, lineColor, bg.init, mode.bold);
                }
                cwritefln("%s:%s", lineNo, line);
            }
        }
    }
}

template DeclareType(string ftype, string inputs, string names)
{
    const char[] DeclareType = format("""
    bool use_%s = false;
    bool no_%s = false;
    getopt(args,
           std.getopt.config.passThrough,
           \"%s\", &use_%s, \"no%s\", &no_%s);
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
    typeOptions ~= \"    --[no]%-12s  %s %s\n\";
""", ftype, ftype, ftype, ftype, ftype, ftype, ftype, inputs, names, inputs, names, ftype, inputs, names, ftype, inputs, names);
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
    bool show_version = false;

    bool reverse = false;
    bool literal = false;
    bool case_insensitive = false;
    bool word_regex = false;
    bool no_recurse = false;
    bool follow = false;

    bool name_only = false;
    bool no_color = false;
    bool with_filename = true;
    bool no_filename = false;

    bool silent = false;

    bool find_files = false;
    bool sort_files = false;

    int[string] defaultExts;
    int[string] defaultNames;
    int[string] userExts;
    int[string] userNames;

    mixin(DeclareType!("ada", ".ada .adb .ads", ""));
    mixin(DeclareType!("asm", ".asm .s", ""));
    mixin(DeclareType!("asp", ".asp", ""));
    mixin(DeclareType!("aspx", ".master .ascx .asmx .aspx .svc", ""));
    mixin(DeclareType!("batch", ".bat .cmd", ""));
    mixin(DeclareType!("cc", ".c .h", ""));
    mixin(DeclareType!("cfmx", ".cfc .cfm .cfml", ""));
    mixin(DeclareType!("clojure", ".clj", ""));
    mixin(DeclareType!("cmake", ".cmake", "CMakeLists.txt"));
    mixin(DeclareType!("coffee", ".coffee", ""));
    mixin(DeclareType!("cpp", ".cpp .cc .cxx .c++ .hpp .tpp .hh .h .hxx", ""));
    mixin(DeclareType!("csharp", ".cs", ""));
    mixin(DeclareType!("css", ".css", ""));
    mixin(DeclareType!("dd", ".d", ""));
    mixin(DeclareType!("dart", ".dart", ""));
    mixin(DeclareType!("delphi", ".pas .int .dfm .nfm .dof .dpk .dproj .groupproj .bdsgroup .bdsproj", ""));
    mixin(DeclareType!("elisp", ".el", ""));
    mixin(DeclareType!("elixir", ".ex .exs", ""));
    mixin(DeclareType!("erlang", ".erl .hrl", ""));
    mixin(DeclareType!("fortran", ".f .f77 .f90 .f95 .f03 .for .ftn .fpp", ""));
    mixin(DeclareType!("fsharp", ".fs .fsx", ""));
    mixin(DeclareType!("go", ".go", ""));
    mixin(DeclareType!("groovy", ".groovy .gtmpl .gpp .grunit .gradle", ""));
    mixin(DeclareType!("haskell", ".hs .lhs", ""));
    mixin(DeclareType!("hh", ".h", ""));
    mixin(DeclareType!("html", ".html .htm", ""));
    mixin(DeclareType!("hy", ".hy", ""));
    mixin(DeclareType!("java", ".java .properties", ""));
    mixin(DeclareType!("js", ".js", ""));
    mixin(DeclareType!("json", ".json", ""));
    mixin(DeclareType!("jsp", ".jsp .jspx .jhtm .jhtml", ""));
    mixin(DeclareType!("less", ".less", ""));
    mixin(DeclareType!("lisp", ".lisp .lsp .cl", ""));
    mixin(DeclareType!("lua", ".lua", ""));
    mixin(DeclareType!("make", ".mk .make", "makefile Makefile GNUmakefile"));
    mixin(DeclareType!("matlab", ".m", ""));
    mixin(DeclareType!("md", ".md .mkd", ""));
    mixin(DeclareType!("nimrod", ".nim", ""));
    mixin(DeclareType!("objc", ".m .h", ""));
    mixin(DeclareType!("objcpp", ".mm .h", ""));
    mixin(DeclareType!("ocaml", ".ml .mli", ""));
    mixin(DeclareType!("parrot", ".pir .pasm .pmc .ops .pod .pg .tg", ""));
    mixin(DeclareType!("perl", ".pl .pm .pod .t .psgi", ""));
    mixin(DeclareType!("php", ".php .phpt .php3 .php4 .php5 .phtml", ""));
    mixin(DeclareType!("plone", ".pt .cpt .metadata .cpy .py", ""));
    mixin(DeclareType!("powershell", ".ps1 .psd1 .psm1 .psc1", ""));
    mixin(DeclareType!("py", ".py", ""));
    mixin(DeclareType!("rr", ".R", ""));
    mixin(DeclareType!("racket", ".rkt .scm .ss .sch", ""));
    mixin(DeclareType!("rake", "", "Rakefile"));
    mixin(DeclareType!("rst", ".rst .txt", ""));
    mixin(DeclareType!("ruby", ".rb .rhtml .rjs .rxml .erb .rake .spec", "Rakefile"));
    mixin(DeclareType!("rust", ".rs", ""));
    mixin(DeclareType!("sass", ".sass", ""));
    mixin(DeclareType!("scala", ".scala", ""));
    mixin(DeclareType!("scheme", ".scm .ss", ""));
    mixin(DeclareType!("shell", ".sh .bash .csh .tcsh .ksh .zsh .fish", ""));
    mixin(DeclareType!("smalltalk", ".st", ""));
    mixin(DeclareType!("sql", ".sql .ctl", ""));
    mixin(DeclareType!("swig", ".i", ""));
    mixin(DeclareType!("tcl", ".tcl .itcl .itk", ""));
    mixin(DeclareType!("tex", ".tex .cls .sty", ""));
    mixin(DeclareType!("textile", ".textile", ""));
    mixin(DeclareType!("vb", ".bas .cls .frm .ctl .vb .resx", ""));
    mixin(DeclareType!("verilog", ".v .vh .sv", ""));
    mixin(DeclareType!("vhdl", ".vhd .vhdl", ""));
    mixin(DeclareType!("vim", ".vim", ""));
    mixin(DeclareType!("xml", ".xml .dtd .xsl .xslt .ent", ""));
    mixin(DeclareType!("yaml", ".yaml .yml", ""));

    try
    {
        getopt(args,
           std.getopt.config.caseSensitive,
           "help", &help,
           "help-types", &help_types,
           "version", &show_version,
           "reverse|v", &reverse,
           "literal|Q", &literal,
           "case-insensitive|i", &case_insensitive,
           "word-regex|w", &word_regex,
           "no-recurse|n", &no_recurse,
           "follow", &follow,
           "name-only|g", &name_only,
           "no-color", &no_color,
           "with-filename|H", &with_filename,
           "no-filename|h", &no_filename,
           "silent|s", &silent,
           "find-files|f", &find_files,
           "sort-files|g", &sort_files,
        );
    }
    catch (object.Exception e)
    {
        writeln(e.msg);
        write(usage);
        writeln(doc);
        return -1;
    }

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

    if (show_version)
    {
        writeln("0.4.0");
        return 0;
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
        if (!silent)
        {
            writeln("Unknown file: ", files[0]);
        }
        return -1;
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


    if (userExts.length > 0 || userNames.length > 0)
    {
        defaultExts = userExts;
        defaultNames = userNames;
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
                                          reverse, name_only, no_filename, !no_color);
                break;
            case BOM.UTF8:
            default:
                searchOneFileStream!char(inp, filename, matcher,
                                         reverse, name_only, no_filename, !no_color);
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
