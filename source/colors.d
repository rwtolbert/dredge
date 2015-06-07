//  grep-like tool written in D.
//
//  Copyright (c) 2014, 2015 Bob Tolbert, bob@tolbert.org
//  Licensed under terms of MIT license (see LICENSE-MIT)
//
//  https://github.com/rwtolbert/sift
//
import std.stdio;
import std.algorithm;

import colorize;
import docopt;

struct ColorOpts
{
    bool showColor;
    string lineColor;
    string fileColor;
    string matchColor;
}

string allowedColors = "    black, white, red, green, blue, cyan, yellow, magenta,
    light_red, light_green, light_blue, light_cyan, light_yellow, light_magenta";

void colorExit(string color)
{
    import std.c.stdlib;

    writefln("unexpected color: %s", color);
    writeln("Color choices:");
    writeln(allowedColors);
    exit(1);
}

public ColorOpts getColors(docopt.ArgValue[string] flags)
{
    ColorOpts colorOpts;

    colorOpts.showColor = flags["--no-color"].isFalse;

    colorOpts.lineColor = flags["--line-color"].toString;
    if (find(allowedColors, colorOpts.lineColor) == [])
    {
        colorExit(colorOpts.lineColor);
    }

    colorOpts.fileColor = flags["--filename-color"].toString;
    if (find(allowedColors, colorOpts.fileColor) == [])
    {
        colorExit(colorOpts.fileColor);
    }

    colorOpts.matchColor = flags["--match-color"].toString;
    if (find(allowedColors, colorOpts.matchColor) == [])
    {
        colorExit(colorOpts.matchColor);
    }

    colorOpts.matchColor = format("bg_%s", colorOpts.matchColor);

    return colorOpts;
}
