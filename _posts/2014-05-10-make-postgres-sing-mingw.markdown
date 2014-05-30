---
author: Michael Paquier
comments: true
lastmod: 2014-05-10
date: 2014-05-10 4:58:23+00:00
layout: post
type: post
slug: make-postgres-sing-mingw
title: 'Make Postgres sing with MinGW on Windows'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- platform
- microsoft
- windows
- 7
- mingw
- compilation
- path
- environment
---
Community usually lacks developers on Windows able to test and provide
feedback on patches that are being implemented. Actually, by seeing bug
reports from users on Windows on a daily basis (not meaning that each
report is really a bug occurring only on this platform but that there
are many users of it), having more people in the field would be great.

Doing development on a different platform does not usually mean a lot
of things:

  * Compiling manually code with a patch and check if a feature is really
working as expected on a platform. This would be a more natural process
than waiting for the [buildfarm](buildfarm.postgresql.org/cgi-bin/show_failures.pl)
to become red with a Windows-only failure.
  * Helping people with their new features. A patch could be rejected
because it proposes something that is not cross-platform.
  * Getting new buildfarm machines publishing results that developers could
use to stabilize code properly.

Either way, jumping from a development platform to another (especially
with already years of experience doing Linux/Unix things) may not be that
straight-forward, and even quite painful if this platform has its code
closed as you may not be able to do everything you want with it to satisfy
your needs.

PostgreSQL provides many ways to be able to [compile its code on Windows]
(http://www.postgresql.org/docs/devel/static/install-windows.html)
for quite a long time now, involving for example the Windows SDK and even
Visual C++ (MSVC), but as well another, more hacky way using MinGW. This
may be even an easier way to enter in the world of Windows development
if you are used to Unix-like OSes as you do not need to rely on some
externally-developed SDK and still need to type by yourself commands
like ./configure and make.

First of all, once you have your hands on a Windows box, perhaps the
best thing to do is to install [msysGit](https://code.google.com/p/msysgit/)
that really helps to provide an experience of Git on Windows close to
what you can live on Unix/Linux platforms. The console provided is not
perfect (need to use the Edit->[Mark|Paste] instead of a plain Ctrl-[C|V]
for any copy paste operation), but this is better than the native Command
Prompt of Windows if you are not used to it. Also, one thing to not forget
is that the paths to each disk are not prefixed with "C:\PATH" but with
/c/$PATH.

Then, continue with the [installation of MinGW]
(http://www.postgresql.org/docs/devel/static/installation-platform-notes.html#INSTALLATION-NOTES-MINGW).
Simply download it and then install it in a custom folder like. Something
like 7-zip is helpful to extract the content from tarballs. You may as
well consider another option to get 64-bit binaries with for example
[MinGW-w64](http://mingw-w64.sourceforge.net/). Some extra instructions
on how to use it are available [here]
(http://sourceforge.net/apps/trac/mingw-w64/wiki/GeneralUsageInstructions).

Even after deploying a MinGW build, you may need a [proper make command]
(http://sourceforge.net/apps/trac/mingw-w64/wiki/Make) as it may not be
available in what you downloaded (that's actually what I noticed with a
MinGW-w64 build). This can for example be taken from one of the stable
snapshots of MinGW after renaming what is present there properly (make
commands are renamed to not conflict with MSYS).

Note as well that the Postgres wiki has some [additional notes]
(https://wiki.postgresql.org/wiki/Building_With_MinGW) you may
find helpful.

It is usually adviced to deploy MinGW in a path like "C:\mingw" but this
is up to you as long as its binary folder is included in PATH, resulting
in that with msysgit for example:

    export PATH=$PATH:/c/mingw/bin

Once you got that done, fetch the code from [Postgres git repository]
(https://github.com/postgres/postgres) and begin the real work. Here
are a couple of things to know though when beginning that.

First, the configure command should enforce a couple of environment
to make the build work smoothly with msysGit. Also a value should be
provided to "--host" to be able to detect the compiler shipped with
MinGW. This results in a configure command similar to that:

    PERL=perl \
        BISON=bison \
        FLEX=flex \
        MKDIR_P="mkdir -p" \
        configure --host=x86_64-w64-mingw32 --without-zlib

Note as well that zlib is disabled for simplicity.

Once compilation has been done, be sure to change as well the calls
of "$(SHELL)" to "bash" like that in src/Makefile.global:

    sed -i "s#\$(SHELL)#bash#g" src/Makefile.global

All those things do not actually require to modify Postgres core code,
so it is up to you to modify your build scripts depending on your needs.

There are as well a couple of things to be aware if you try to backport
scripts that you have been using in other environments (some home-made
scripts have needed patches in my case):

  * Be sure to update any newline of the type "\n" with "\r\n", this will
avoid parsing failures when inserting multiple lines at the same time inside
a single file like pg_hba.conf.
  * USER is not a valid environment variable, USERNAME is.
  * Servers cannot start if kicked by users having Administrator privileges
  * Compilation is slow... 

Once compilation works correctly, you will be able to get something like
that:

    =# SELECT substring(version(), 1, 73);
                                     substring
    ---------------------------------------------------------------------------
     PostgreSQL 9.4devel on x86_64-w64-mingw32, compiled by x86_64-w64-mingw32
    (1 row)

Then you can congratulate yourself and enjoy a glass of wine.
