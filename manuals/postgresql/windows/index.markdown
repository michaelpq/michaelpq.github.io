---
author: Michael Paquier
date: 2014-05-12 14:14:18+00:00
layout: page
type: page
slug: windows
title: PostgreSQL - Windows
tags:
- postgres
- postgresql
- development
- microsoft
- windows
- closed
- environment
- programing
- msvc
- mingw
- source
---
Here are a couple of tips to remember when developing PostgreSQL on
Windows.

### MinGW

Here is how to do development of PostgreSQL with MinGW. First install a
version of MinGW following the instructions for example [here]
(https://sourceforge.net/apps/trac/mingw-w64/wiki/GeneralUsageInstructions).
Those instructions are for MinGW-w64 that can be used to get 64b binaries
of PostgreSQL.

Here are also other links to consider:

  * Postgres wiki, indicating a [MinGW build]
(https://wiki.postgresql.org/wiki/Building_With_MinGW) that can be used
for development. A snapshot like mingw-w64-bin_i686-mingw_20111220.zip
is proved to work. This does not contain make commands though, so...
  * make command can be found following [those instructions]
(https://sourceforge.net/apps/trac/mingw-w64/wiki/Make), then fetch it
from one of the stabls releases like x64-4.8.1-release-posix-seh-rev5.7z.

Then install MinGW in a path like c:\\mingw and add it to Path (or PATH
for msysgit). msysgit is btw recommended to facilitate development
with MinGW as it is necessary to begin to do things like configure and
make [install] manually. Compilation is as well slower than MSVC outputs.

Do not forget that configure needs --host=x86_64-w64-mingw32 to be
specified to be able to find a compiler. Postgres documentation offers
as well some tips [like that]
(https://www.postgresql.org/docs/devel/static/installation-platform-notes.html#INSTALLATION-NOTES-MINGW)

### MSVC

Building PostgreSQL with MSVC is actually easier, and faster than MinGW.

Documentation also provides a [detailed manual]
(https://www.postgresql.org/docs/devel/static/install-windows-full.html)
of how to do things properly.

There is nothing much to say, just be sure to launch all the installation
commands from src/tools/msvc in the Windows SDK command prompt. As well,
the MSVC scripts need absolutely to use stuff from [ActiveState Perl]
(https://www.activestate.com). Use the free Standard Distribution. Be as
well sure that the perl version from msysgit is *not* in Path/PATH as
the MSVC scripts do not work with it.
