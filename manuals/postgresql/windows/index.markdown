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

### Chocolatey and meson

ActiveState does not offer a perl binary in a PATH by default, so first
run that from PowerShell:

    state activate --default

A different, and much more appealing alternative is to use StrawberryPerl
these days.  Really, ActivePerl integration is honestly BS because it requires
a project to be activated with a "state activate --default" command to give
access to a "perl" command, located within the local cache data (AppData\)
for the OS user.

Using Chocolatey seems to be the only alternative with meson:

    choco install winflexbison
    choco install sed
    choco install gzip
    # This one is necessary for a "perl" command.
    choco install strawberryperl
    # This one is necessary for a "diff" command and the regression tests.
    choco install diffutils

Something like that may be required for the automatic dependency check for
PL/Python.  But it may be preferable to just disable the switch entirely:

    choco install python

Then run a command like that for the installation:

    meson setup -Dplpython=disabled -Dprefix=C:\Users\Administrator\pgsql builddir
    cd builddir/
    meson compile
    meson install

Note that the compiler detected will depend on the terminal where the meson
commands are run: using a simple Command Prompt will likely find out
Chocolatey's gcc version.  In order to use Visual Studio's compiler, using
the Command Prompt for VS is mandatory.

A run of the tests can be done as follows:

    cd builddir/
    meson test

Here is an equivalent of installcheck:

    meson test --setup running regress-running/regress
