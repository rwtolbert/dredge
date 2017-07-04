//  grep-like tool written in D.
//
//  Copyright (c) 2014-2017 Bob Tolbert, bob@tolbert.org
//  Licensed under terms of MIT license (see LICENSE-MIT)
//
//  https://github.com/rwtolbert/dredge
//
import std.stdio;
import std.encoding;

import docopt;

version(Windows)
{
    extern(C) int isatty(int);
}

public bool isStdin()
{
    version(Posix)
    {
        import core.sys.posix.unistd;
        return (isatty(0) != 0);
    }
    version(Windows)
    {
        return (isatty(0) != 0);
    }
}

public bool isStdout()
{
    version(Posix)
    {
        import core.sys.posix.unistd;
        return (isatty(1) != 0);
    }
    version(Windows)
    {
        return (isatty(1) != 0);
    }
}

public bool isStderr()
{
    version(Posix)
    {
        import core.sys.posix.unistd;
        return (isatty(2) != 0);
    }
    version(Windows)
    {
        return (isatty(2) != 0);
    }
}

public bool hasStdinData()
{
    version(Windows)
    {
        import core.sys.windows.windows;
        DWORD events = 0;           // how many events took place
        INPUT_RECORD input_record;  // a record of input events
        DWORD input_size = 1;       // how many characters to read

        if (PeekConsoleInputA(GetStdHandle(STD_INPUT_HANDLE),
                              &input_record,
                              input_size,
                              &events) == 0)
        {
            return true;
        }
    }
    version(Posix)
    {
        import core.sys.posix.sys.select;
        import core.sys.posix.sys.time;

        fd_set read,write,except;
        FD_ZERO(&read);
        FD_ZERO(&write);
        FD_ZERO(&except);
        FD_SET(0,&read); // stdin

        timeval timeout;
        timeout.tv_sec=0;
        timeout.tv_usec=0;

        if (select(1,&read,&write,&except,&timeout) != 0)
        {
            return true;
        }
    }
    return false;
}


void dumpFlags(docopt.ArgValue[string] flags)
{
    foreach(k, v; flags)
    {
        writefln("%s: %s", k, v);
    }
}
