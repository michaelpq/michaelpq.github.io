---
author: Michael Paquier
date: 2013-05-17 11:56:27+00:00
layout: page
type: page
slug: windows
title: Windows
tags:
- guide
- development
- windows
- tips
- things
- recalling
- command
- code
- programing
- exe
- cmd
- msi
---
Here are a couple of tips useful to remember when doing development on
Windows.

### Settings

First, when using a Japanese keyboard, you might want to set up correctly
a [JP106 keyboard](http://support.microsoft.com/kb/927824/en-us).

Windows does not use PATH, but Path to detect the folders where binaries
are automatically looked for. In order to modify it, a simple method
consists in doing.

  * Left-click on "My Computer" -> "Properties"
  * Click "Advanced System Settings"
  * In tab "System Properties" click the "Environment Variables"
  * Update Path as followed: Path => c:\path1;c:\path2;etc.

### Softwares

Installing emacs on Windows is damn easy as GNU proposes packages to
deploy [here](http://ftp.gnu.org/gnu/emacs/windows/).

7zip is essential for your survival as it is extrenely useful for
decompressing things that you need to install like emacs.

As an antivirus, [clamwin](http://www.clamwin.com/) is an open source
solution free of use.

[msysgit](http://msysgit.github.io/) provides an excellent way to have a
Unix-like environment on Windows. [Home](https://github.com/michaelpq/home)
has as well on its branch windows, scripts already compatible with Windows
that are derived from the ones in the Unix/Linux branches. This contains
as well Perl and Bison. Perl is *not* compatible with MSVC so be sure to
rename it to something else such as there are no conflicts with Active
State which is solid rock and used with MSVC (msysgit's Perl does not
work properly because of a lack of libraries for Win32).

### Commands

Environment variables can be viewed with command:

    set

Command to launch something not in Path with cmd.exe:

    cmd /c c:\path\to\bin\command --args

Kick an installation with command line:

    msiexec /i product.msi PARAM1=$VAL1 PARAM2=$VAL2
