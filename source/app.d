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

struct FileType
{
    string[] extensions;
    string[] names;
}

FileType[string] getTypes()
{
    FileType[string] types = [
        "--ada"    : FileType([".ada", ".adb", ".ads"], []),
        "--asm"    : FileType([".asm", ".s"], []),
        "--asp"    : FileType([".asp"], []),
        "--aspx"   : FileType([".master", ".ascx", ".asmx", ".aspx", ".svc"], []),
        "--batch"  : FileType([".bat", ".cmd"], []),
        "--c"      : FileType([".c", ".h"], []),
        "--cfmx"   : FileType([".cfc", ".cfm", ".cfml"], []),
        "--clojure": FileType([".clj"], []),
        "--cmake"  : FileType([".cmake"], ["CMakeLists.txt"]),
        "--coffee" : FileType([".coffee"], []),
        "--cpp"    : FileType([".h", ".hh", ".cc", ".cpp", ".cxx", ".c++", ".hpp", ".hxx", ".tpp"], []),
        "--csharp" : FileType([".cs"], []),
        "--css"    : FileType([".css"], []),
        "--d"      : FileType([".d"], []),
        "--dart"   : FileType([".dart"], []),
        "--delphi" : FileType([".pas",".int",".dfm",".nfm",".dof",".dpk",".dproj",".groupproj",".bdsgroup",".bdsproj"],[]),
        "--elisp"  : FileType([".el"], []),
        "--elixir" : FileType([".ex", ".exs"], []),
        "--erlang" : FileType([".erl", ".hrl"], []),
        "--fortran": FileType([".f", ".f77", ".f90", ".f95", ".f03", ".for", ".ftn", ".fpp"], []),
        "--fsharp" : FileType([".fs", ".fsx"], []),
        "--go"     : FileType([".go"], []),
        "--groovy" : FileType([".groovy", ".gtmpl", ".gpp", ".grunit", ".gradle"], []),
        "--haskell": FileType([".hs", ".lhs"], []),
        "--hh"     : FileType([".h"], []),
        "--html"   : FileType([".html", ".htm"], []),
        "--hy"     : FileType([".hy"], []),
        "--java"   : FileType([".java", ".properties"], []),
        "--js"     : FileType([".js"], []),
        "--json"   : FileType([".json"], []),
        "--jsp"    : FileType([".jsp", ".jspx", ".jhtm", ".jhtml"], []),
        "--less"   : FileType([".less"], []),
        "--lisp"   : FileType([".lisp", ".lsp"], []),
        "--lua"    : FileType([".lua"], []),
        "--make"   : FileType([".mk", ".mak"], ["makefile", "Makefile", "GNUmakefile"]),
        "--matlab" : FileType([".m"], []),
        "--md"     : FileType([".mkd", ".md"], []),
        "--objc"   : FileType([".m", ".h"], []),
        "--objcpp" : FileType([".mm", ".h"], []),
        "--ocaml"  : FileType([".ml", ".mli"], []),
        "--parrot" : FileType([".pir", ".pasm",  ".pmc", ".ops", ".pod", ".pg", ".tg"], []),
        "--perl"   : FileType([".pl", ".pm", ".pod", ".t", ".psgi"], []),
        "--php"    : FileType([".php", ".phpt", ".php3", ".php4", ".php5", ".phtml"], []),
        "--ninja"  : FileType([".ninja"], []),
        "--powershell" : FileType([".ps1", ".psm1", ".psd1", ".psc1"], []),
        "--py"     : FileType([".py"], []),
        "--r"      : FileType([".r"], []),
        "--ruby"   : FileType([".rb", ".rhtml", ".rjs", ".rxml", ".rake", ".spec"], ["Rakefile"]),
        "--rust"   : FileType([".rs"], []),
        "--sass"   : FileType([".sass", ".scss"], []),
        "--scala"  : FileType([".scala"], []),
        "--scheme" : FileType([".scm", ".ss"], []),
        "--shell"  : FileType([".sh", ".bash", ".csh", ".tcsh", ".ksh", ".zsh", ".fish"], []),
        "--smalltalk" : FileType([".st"], []),
        "--sql"    : FileType([".sql", ".ctl"], []),
        "--tcl"    : FileType([".tcl", ".itcl", ".itk"], []),
        "--tex"    : FileType([".tex", ".cls",  ".sty"], []),
        "--textile": FileType([".textile"], []),
        "--swift"  : FileType([".swift"], []),
        "--swig"   : FileType([".i"], []),
        "--vb"     : FileType([".bas", ".cls", ".frm", ".ctl", ".vb", ".resx"], []),
        "--verilog": FileType([".v", ".vh", ".sv"], []),
        "--vhdl"   : FileType([".vhd", ".vhdl"], []),
        "--vim"    : FileType([".vim"], []),
        "--xml"    : FileType([".xml", ".dtd", ".xsl", ".xslt", ".ent"], []),
        "--yaml"   : FileType([".yaml", ".yml"], []),
        ];
    return types;
}

string getTypeOptions(FileType[string] types)
{
    string res = "\nFile type options:\n";
    string[] keys = types.keys;
    sort(keys);  // from std.algorithm;
    foreach(k; keys)
    {
        string exts = join(types[k].extensions, " ");
        res ~= format("    %-13s", k);
        if (types[k].extensions.length > 0)
        {
            res ~= " " ~ join(types[k].extensions, " ");
        }
        if (types[k].names.length > 0)
        {
            res ~= " " ~ join(types[k].names, " ");
        }
        res ~= "\n";
    }
    return res;
}

void getDefaultExtensions(ref int[string] exts, ref int[string] names,
                          const FileType[string] types)
{
    foreach(k,v; types)
    {
       foreach(ext; v.extensions)
       {
           exts[ext] = 1;
       }
       foreach(name; v.names)
       {
           names[name] = 1;
       }
    }
}

void getUserExtensions(ref int[string] exts, ref int[string] names,
                       const docopt.ArgValue[string] arguments,
                       const FileType[string] types)
{
    foreach(arg, value; arguments)
    {
        if (arg in types && value.isTrue())
        {
            foreach(ext; types[arg].extensions)
            {
                exts[ext] = 1;
            }
            foreach(name; types[arg].names)
            {
                names[name] = 1;
            }
        }
    }
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
        if (printMatch || printNoMatch)
        {
            if (first)
            {
                if (arguments["--name-only"].isTrue())
                {
                    writeln(filename);
                }
                else
                {
                    if (arguments["--no-filename"].isFalse())
                    {
                        writeln(format("\n%s", filename));
                    }
                }
                first = false;
            }
            if (arguments["--name-only"].isFalse())
            {
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
    -f                     Only print files selected.
    --sort-files           Sort the files found.

File inclusion options:
    -n, --no-recurse       No descending into subdirectories
    --follow               Follow symlinks.  Default is off.

    ";

    auto types = getTypes();
    auto typeOptions = getTypeOptions(types);

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

    auto allDoc = usage ~ doc ~ typeOptions;
    auto arguments = docopt.docopt(allDoc, args[1..$], false, "0.2.0");

    if (arguments["--help"].isTrue())
    {
        write(usage);
        writeln(doc);
        return 0;
    }

    if (arguments["--help-types"].isTrue())
    {
        write(usage);
        writeln(typeOptions);
        return 0;
    }

//    writeln(arguments);

    auto spanMode = SpanMode.breadth;
    if (arguments["--no-recurse"].isTrue())
    {
        spanMode = SpanMode.shallow;
    }
    bool follow = arguments["--follow"].isTrue();

    if (arguments["FILES"].isEmpty())
    {
        arguments["FILES"].add(".");
    }

    int[string] defaultExts;
    int[string] defaultNames;
    getUserExtensions(defaultExts, defaultNames, arguments, types);
    if (defaultExts.length == 0 && defaultNames.length == 0)
    {
        getDefaultExtensions(defaultExts, defaultNames, types);
    }

//    writeln(arguments["FILES"]);

    auto FILES = arguments["FILES"].asList();
    try
    {
        if (FILES.length == 1 && FILES[0] == "-")
        {
            arguments["--no-filename"] = new docopt.ArgValue(true);
        }
        else if (FILES.length == 1 && FILES[0].isFile && arguments["--with-filename"].isFalse())
        {
            arguments["--no-filename"] = new docopt.ArgValue(true);
        }
        else if (arguments["--with-filename"].isTrue())
        {
            arguments["--no-filename"] = new docopt.ArgValue(false);
        }
    }
    catch(std.file.FileException e)
    {
        if (arguments["-s"].isFalse)
        {
            writeln("Unknown file: ", FILES[0]);
        }
        return -1;
    }

    uint[string] ignoreDirs = [".git":1, ".hg":1, ".svn":1, ".dub":1, "CVS":1, ".DS_Store":1];
    string[] fileList;
    foreach(item; FILES)
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
                auto files = dirEntries(thisDir, spanMode, follow);
                foreach(fileName; files)
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
            if (arguments["-s"].isFalse)
            {
                writeln("Unknown file: ", item);
            }
        }
    }

    if (arguments["--sort-files"].isTrue)
    {
        std.algorithm.sort(fileList);
    }

    if (arguments["-f"].isTrue)
    {
        foreach(filename; fileList)
        {
            writeln(filename);
        }
        return 0;
    }

    auto pattern = arguments["PATTERN"].toString();
    if (arguments["--literal"].isTrue())
    {
        pattern = translate(pattern, metaTable);
    }
    if (arguments["--word-regex"].isTrue())
    {
        pattern = format("\\b%s\\b", pattern);
    }
    auto flags = "";
    if (arguments["--case-insensitive"].isTrue())
    {
        flags ~= "i";
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
                searchOneFileStream!wchar(inp, filename, wmatcher, arguments);
                break;
            case BOM.UTF8:
            default:
                searchOneFileStream!char(inp, filename, matcher, arguments);
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
