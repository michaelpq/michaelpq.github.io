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

To apply a minor update:

    msiexec /fvomus updated_product.msi

Getting the version number of a binary or library can be tedious, first
create the following vbscript, called for example my_script.vbs:

    Set args = WScript.Arguments
    Set objFSO = CreateObject("Scripting.FileSystemObject")
    Wscript.Echo objFSO.GetFileVersion(args.Item(0))

Then run this command:

    cscript /nologo my_script.vbs file_to_check.exe

### Tasks

Print list of processes running as tasks.

    tasklist

Print list of processes running given executable.

    tasklist /FI "IMAGENAME eq prog.exe"

Print a given service listed in a task.

    tasklist /svc /fi "SERVICE eq $SERVICE_NAME"

Kill a process.

    taskkill /PID $PID_NUMBER /f

### Services

Start or stop a service.

    sc start|stop $SERVICE_NAME

Query a service to test it.

    sc query $SERVICE_NAME

### Permissions

Deny access to a folder for a given user.

    icacls c:\to\path /deny %USERNAME%:(D)

Check access permissions to this path.

    rd /S /Q c:\to\path
