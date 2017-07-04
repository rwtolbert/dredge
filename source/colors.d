//  grep-like tool written in D.
//
//  Copyright (c) 2014, 2015, 2017 Bob Tolbert, bob@tolbert.org
//  Licensed under terms of MIT license (see LICENSE-MIT)
//
//  https://github.com/rwtolbert/dredge
//
import std.stdio;
import std.algorithm;

import colorize;
import docopt;

import utils;

struct ColorOpts
{
    bool showColor;
    fg lineColor;
    fg fileColor;
    bg matchColor;
}

string allowedColors = "    black, white, red, green, blue, cyan, yellow, magenta,
    light_red, light_green, light_blue, light_cyan, light_yellow, light_magenta";

fg fgCode(const string name) pure
{
  fg code;
  switch(name)
  {
    case "black"  : code = fg.black; break;
    case "red"    : code = fg.red; break;
    case "green"  : code = fg.green; break;
    case "yellow" : code = fg.yellow; break;
    case "blue"   : code = fg.blue; break;
    case "magenta": code = fg.magenta; break;
    case "cyan"   : code = fg.cyan; break;
    case "white"  : code = fg.white; break;

    case "light_black"  : code = fg.light_black; break;
    case "light_red"    : code = fg.light_red; break;
    case "light_green"  : code = fg.light_green; break;
    case "light_yellow" : code = fg.light_yellow; break;
    case "light_blue"   : code = fg.light_blue; break;
    case "light_magenta": code = fg.light_magenta; break;
    case "light_cyan"   : code = fg.light_cyan; break;
    case "light_white"  : code = fg.light_white; break;
    default: assert(0);
  }
  return code;
}

bg bgCode(const string name) pure
{
  bg code;
  switch(name)
  {
    case "black"  : code = bg.black; break;
    case "red"    : code = bg.red; break;
    case "green"  : code = bg.green; break;
    case "yellow" : code = bg.yellow; break;
    case "blue"   : code = bg.blue; break;
    case "magenta": code = bg.magenta; break;
    case "cyan"   : code = bg.cyan; break;
    case "white"  : code = bg.white; break;

    case "light_black"  : code = bg.light_black; break;
    case "light_red"    : code = bg.light_red; break;
    case "light_green"  : code = bg.light_green; break;
    case "light_yellow" : code = bg.light_yellow; break;
    case "light_blue"   : code = bg.light_blue; break;
    case "light_magenta": code = bg.light_magenta; break;
    case "light_cyan"   : code = bg.light_cyan; break;
    case "light_white"  : code = bg.light_white; break;
    default: assert(0);
  }
  return code;
}


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
    if (!isStdout())
    {
        colorOpts.showColor = false;
    }

    string name = flags["--line-color"].toString;
    if (find(allowedColors, name) == [])
    {
        colorExit(name);
    }
    colorOpts.lineColor = fgCode(name);

    name = flags["--filename-color"].toString;
    if (find(allowedColors, name) == [])
    {
        colorExit(name);
    }
    colorOpts.fileColor = fgCode(name);

    name = flags["--match-color"].toString;
    if (find(allowedColors, name) == [])
    {
        colorExit(name);
    }
    colorOpts.matchColor = bgCode(name);

    return colorOpts;
}
