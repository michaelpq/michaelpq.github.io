---
author: Michael Paquier
lastmod: 2014-08-20
date: 2014-08-20 06:30:23+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-versioning-improvement-windows
title: 'Postgres 9.5 feature highlight - Versioning Improvements on Windows'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- 9.5
- new
- feature
- windows
- os
- version
- file
- description
- improvement
- upgrade
- track

---

Some good news for packagers of PostgreSQL on Windows with many improvements
in versioning that are showing up in 9.5. This is the result of a couple of
months of work, concluded with the two following commits. The first commit
is covering a major portion of executables and libraries:

    commit: 0ffc201a51395ca71fe429ef86c872850a5850ee
    author: Noah Misch <noah@leadboat.com>
    date: Mon, 14 Jul 2014 14:07:52 -0400
    Add file version information to most installed Windows binaries.

    Prominent binaries already had this metadata.  A handful of minor
    binaries, such as pg_regress.exe, still lack it; efforts to eliminate
    such exceptions are welcome.

This has added versioning for contrib modules, conversion\_procs, most of the
ecpg thingies, WAL receiver and PL languages. And then the final shot has been
done with this commit, for utilities like regression tools or even zic.exe,
part of the timezone code path:

    commit: ee9569e4df1c3bdb6858f4f65d0770783c32a84d
    author: Noah Misch <noah@leadboat.com>
    date: Mon, 18 Aug 2014 22:59:53 -0400
    Finish adding file version information to installed Windows binaries.

    In support of this, have the MSVC build follow GNU make in preferring
    GNUmakefile over Makefile when a directory contains both.

    Michael Paquier, reviewed by MauMau.

This work has basically needed the following things to get correct versioning
coverage when building with either MinGW and MSVC:

  * Addition of PGFILEDESC to have a file description
  * Addition of some WIN32RES in the object list being built by make to
compile the version number.
  * For MSVC, some refactoring of the scripts used for build to have them
pick up correctly PGFILEDESC, and create version files.

Now, the result of this work is directly visible on the files themselves
by looking at the file details in menu "Property" by left-clicking on a
given file, tab "Details". With that, it is possible to see fields for:

  * File Description, for example for adminpack.dll, the description is
  "adminpack - support functions for pgAdmin".
  * Version number, made of 4 integer digits separated by a dot. This is
  the most important part of the patch as this allows tracking a file
  version, something really useful for upgrade purposes. For 9.5, this
  results in for example "9.5.0.14225".
  * Copyright
  * Type
  * etc.

When bundling the compiled files into an msi, it makes their visibility
easier as well if you look at them with utilities of the type orca.

In short, Windows packagers can be ready to remove their custom patches
as such versioning is usually a product-level requirement, facilitating
long-term maintenance.
