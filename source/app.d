//  grep-like tool written in D.
//
//  Copyright (c) 2014, 2015 Bob Tolbert, bob@tolbert.org
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
import std.container;

import docopt;
import colorize;

import utils;
import colors;

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

void getContext(docopt.ArgValue[string] flags,
                ref int before_context,
                ref int after_context)
{
    import std.conv;

    if (!flags["--context"].isNull)
    {
        auto val = flags["--context"].toString;
        before_context = after_context = parse!int(val);
    }
    else
    {
        if (!flags["--before-context"].isNull)
        {
            auto val = flags["--before-context"].toString;
            before_context = parse!int(val);
        }
        if (!flags["--after-context"].isNull)
        {
            auto val = flags["--after-context"].toString;
            after_context = parse!int(val);
        }
    }
}

char[] getOneLine(T : char)(InputStream inp)
{
    return inp.readLine();
}

wchar[] getOneLine(T : wchar)(InputStream inp)
{
    return inp.readLineW();
}

void writeUnmatchedLine(T)(ulong lcount, T[] line, bool writeLineNo, const ColorOpts colorOpts)
{
    if (writeLineNo)
    {
        string lineNo = format("%d", lcount);
        if (colorOpts.showColor)
        {
            lineNo = color(lineNo, colorOpts.lineColor);
        }
        cwritefln("%s-%s", lineNo, line);
    }
    else
    {
        cwritefln("%s", line);
    }
}

void writeMatchedLine(T)(ulong lcount, T[] line, Regex!T matcher, bool writeLineNo,
                         const ColorOpts colorOpts)
{
    if (colorOpts.showColor)
    {
        line = replaceAll(line, matcher, color("$0", colorOpts.matchColor).color("black"));
    }

    if (writeLineNo)
    {
        string lineNo = format("%d", lcount);
        if (colorOpts.showColor)
        {
            lineNo = color(lineNo, colorOpts.lineColor);
        }
        cwritefln("%s:%s", lineNo, line);
    }
    else
    {
        cwritefln("%s", line);
    }
}

void searchOneFileStream(T)(InputStream inp, const string filename,
                            Regex!T matcher, docopt.ArgValue[string] flags,
                            const ColorOpts colorOpts, int beforeContext, int afterContext)
{
    bool first = true;
    bool reverse = flags["--reverse"].isTrue;
    bool files_with_matches = flags["--files-with-matches"].isTrue;
    bool files_without_match = flags["--files-without-match"].isTrue;
    bool no_filename = flags["--no-filename"].isTrue;

    bool showContext = (beforeContext>0 || afterContext>0);

    if (files_with_matches || files_without_match)
    {
        showContext = false;
    }

    string cfilename = filename;
    if (colorOpts.showColor)
    {
        cfilename = color(cfilename, colorOpts.fileColor);
    }

    bool found = false;

    if (showContext)
    {
        auto beforeArray = Array!(T[])();
        auto afterArray = Array!(T[])();
        T[] this_line = getOneLine!T(inp);
        int lcount = 0;
        ulong last_line_printed = 0;

        while(afterArray.length>0 || !inp.eof())
        {
            lcount++;

            while(afterArray.length < afterContext && !inp.eof())
            {
                afterArray.insertBack(getOneLine!T(inp));
            }

            auto captures = matchAll(this_line, matcher);
            bool printMatch = !captures.empty() && !reverse;
            bool printNoMatch = captures.empty() && reverse;
            if (printMatch || printNoMatch)
            {
                found = true;
                if (first)
                {
                    if (!no_filename)
                    {
                        cwritefln("%s", cfilename);
                    }
                    first = false;
                }

                auto counter = lcount - beforeArray.length();
                if (last_line_printed > 0 && counter > last_line_printed + 1)
                {
                    writeln("--");
                }

                foreach(bline; beforeArray)
                {
                    if (counter > last_line_printed)
                    {
                        writeUnmatchedLine!T(counter, bline, !no_filename, colorOpts);
                        last_line_printed = counter;
                    }
                    counter++;
                }

                if (lcount > last_line_printed)
                {
                    writeMatchedLine!T(lcount, this_line, matcher, !no_filename, colorOpts);
                    last_line_printed = lcount;
                }

                foreach(aline; afterArray)
                {
                    counter++;
                    if (counter > last_line_printed)
                    {
                        if (!matchFirst(aline, matcher).empty())
                        {
                            writeMatchedLine!T(counter, aline, matcher, !no_filename, colorOpts);
                            last_line_printed = counter;
                        }
                        else
                        {
                            writeUnmatchedLine!T(counter, aline, !no_filename, colorOpts);
                            last_line_printed = counter;
                        }
                    }
                }
            }

            if (beforeContext > 0)
            {
                beforeArray.insertBack(this_line);
                while (beforeArray.length > beforeContext)
                {
                    beforeArray = Array!(T[])(beforeArray[1..$]);
                }
            }

            if (afterContext > 0)
            {
                if (afterArray.length > 0)
                {
                    this_line = afterArray.front;
                    afterArray = Array!(T[])(afterArray[1..$]);
                }
            }
            else
            {
                this_line = getOneLine!T(inp);
            }
        }
    }
    else
    {
        foreach(ulong lcount, T[] line; inp)
        {
            auto captures = matchAll(line, matcher);
            bool printMatch = !captures.empty() && !reverse;
            bool printNoMatch = captures.empty() && reverse;
            if (printMatch || printNoMatch)
            {
                found = true;
                if (files_without_match)
                {
                    break;
                }
                if (first)
                {
                    if (files_with_matches)
                    {
                        writeln(filename);
                        break;
                    }
                    else
                    {
                        if (!no_filename)
                        {
                            cwritefln("%s", cfilename);
                        }
                    }
                    first = false;
                }
                if (!files_with_matches && !files_without_match)
                {
                    writeMatchedLine!T(lcount, line, matcher, !no_filename, colorOpts);
                }
            }
        }
    }
    if (found && !files_with_matches && !files_without_match)
    {
        writeln();
    }
    if (!found && files_without_match)
    {
        writeln(filename);
    }
}

template DeclareType(string ftype, string inputs, string names)
{
    const char[] DeclareType = format("""
    bool use_%s = false;
    bool no_%s = false;
    getopt(args,
           std.getopt.config.passThrough,
           \"%s\", &use_%s, \"no-%s\", &no_%s);
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
    typeOptions ~= \"    --[no-]%-12s  %s %s\n\";
""", ftype, ftype, ftype, ftype, ftype, ftype, ftype, inputs, names, inputs, names, ftype, inputs, names, ftype, inputs, names);
}

int main(string[] args)
{
    auto usage = "
Usage: sift [options] PATTERN [FILES ...]
       sift -f [options] [FILES ...]
       sift (-?|--help)
       sift --help-types
       sift --version
    ";

    auto doc = "
Arguments:
    PATTERN     pattern to search for
    FILES       files or directories to search.  [default: .]

Search options:
    -v --reverse                 Reverse the match.
    -Q --literal                 Quote all meta-characters.
    -i --case-insensitive        Case-insensitive match.
    -w --word-regex              Match whole words only.

Output options:
    -H --with-filename           Include filename before match.
    -h --no-filename             No filename before match.
    -l --files-with-matches      Only print FILE names containing matches
    -L --files-without-match     Only print FILE names containing no match
    -A NUM --after-context NUM   Print NUM lines of trailing context after
                                 matching lines.
    -B NUM --before-context NUM  Print NUM lines of leading context before
                                 matching lines.
    -C NUM --context NUM         Print NUM lines of output context.
    --no-color                   No color output
    --filename-color COLOR       Color for filename output  [default: green]
    --line-color COLOR           Color for line numbers     [default: cyan]
    --match-color COLOR          Color for match highlight  [default: yellow]
    -s --silent                  Suppress failure on missing or unreadable file.

Base options:
    -? --help
    --help-types                 Show help on file type flags.
    --version                    Show version and exit.

File find options:
    -f --find-files              Only print files selected.
    --sort-files                 Sort the files found.

File inclusion options:
    -n, --no-recurse             No descending into subdirectories
    --follow                     Follow symlinks.  Default is off.

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
    mixin(DeclareType!("nim", ".nim", ""));
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

    auto flags = docopt.docopt(usage ~ doc, args[1..$], true, "0.4.2");

//    dumpFlags(flags);

    if (flags["--help-types"].isTrue)
    {
        write(usage);
        writeln(typeOptions);
        return 0;
    }
    string[] files;
    if (flags["FILES"].asList.length == 0)
    {
        if (hasStdinData())  // stdin has data from pipe so lets use that
        {
            files = ["-"];
        }
        else
        {
            files = ["."];  // no directory given means use current
        }
    }
    else
    {
        files = flags["FILES"].asList;
    }

    try
    {
        if (files.length == 1 && files[0] == "-")
        {
            flags["--no-filename"] = new docopt.ArgValue(true);
        }
        else if (files.length == 1 && files[0].isFile && flags["--with-filename"].isFalse)
        {
            flags["--no-filename"] = new docopt.ArgValue(true);
        }
        // else if (flags["--with-filename"].isFalse)
        // {
        //     flags["--no-filename"] = new docopt.ArgValue(false);
        // }
    }
    catch(std.file.FileException e)
    {
        if (flags["--silent"].isFalse)
        {
            writeln("Unknown file: ", files[0]);
        }
        return -1;
    }

    auto colorOpts = getColors(flags);

    int before_context = 0;
    int after_context = 0;
    getContext(flags, before_context, after_context);

    auto spanMode = SpanMode.breadth;
    if (flags["--no-recurse"].isTrue)
    {
        spanMode = SpanMode.shallow;
    }

    auto regexFlags = "";
    if (flags["--case-insensitive"].isTrue)
    {
        regexFlags ~= "i";
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
        if (item == ".")
        {
            item = getcwd();
        }
        try
        {
            if (item == "-" || item.isFile)
            {
                fileList ~= item;
            }
            else if (item.isDir)
            {
                auto thisDir = buildNormalizedPath(item);
                auto dirFiles = dirEntries(thisDir, spanMode, flags["--follow"].isTrue);
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
            if (flags["--silent"].isTrue)
            {
                writeln("Unknown file: ", item);
            }
        }
    }

    if (flags["--sort-files"].isTrue)
    {
        std.algorithm.sort(fileList);
    }

    if (flags["--find-files"].isTrue)
    {
        foreach(filename; fileList)
        {
            writeln(filename);
        }
        return 0;
    }

    string pattern = flags["PATTERN"].toString;
    if (flags["--literal"].isTrue)
    {
        pattern = translate(pattern, metaTable);
    }
    if (flags["--word-regex"].isTrue)
    {
        pattern = format("\\b%s\\b", pattern);
    }
    auto matcher = regex(pattern, regexFlags);
    auto wmatcher = regex(std.utf.toUTF16(pattern), regexFlags);

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
                searchOneFileStream!wchar(inp, filename, wmatcher, flags, colorOpts,
                                          before_context, after_context);
                break;
            case BOM.UTF8:
            default:
                searchOneFileStream!char(inp, filename, matcher, flags, colorOpts,
                                         before_context, after_context);
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
// last line
