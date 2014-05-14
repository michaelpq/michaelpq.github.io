---
author: Michael Paquier
comments: true
lastmod: 2014-05-14
date: 2014-05-14 12:41:17+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-msvc-client-installer
title: 'Postgres 9.4 feature highlight: MSVC installer for client binaries and libraries'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- 9.4
- new
- feature
- installation
- windows
- microsoft
- msvc
- binary
- library
- client
- limited
---
Today here is a highlight of a new Postgres 9.4 feature interesting for
developers and companies doing packaging of Postgres on Windows as it
makes possible the installation of client-only binaries and libraries
using MSVC. It has been introduced by this commit:

    commit a7e5f7bf6890fdf14a6c6ecd0854ac3f5f308ccd
    Author: Andrew Dunstan <andrew@dunslane.net>
    Date:   Sun Jan 26 17:03:13 2014 -0500

    Provide for client-only installs with MSVC.

    MauMau.

Enters in the client package all the binaries used to interact directly
with the server (psql, pg_dump, pgbench) and the interface libraries
(libpq, ecpg).

Documentation precisely describes [how to set up]
(http://www.postgresql.org/docs/devel/static/install-windows-full.html)
an environment to compile PostgreSQL on Windows, so in short here is
the new command that you can use from src/tools/msvc in for example a
Windows SDK command prompt:

    install c:\install\to\path client

The command "install" will install by default everything if no keyword
is specified. As a new behavior, the keyword "all" can be used to install
everything, meaning that the following commands are equivalent:

    install c:\install\to\path
    install c:\install\to\path all

After the client installation, you will get the following things
installed:

    $ ls /c/install/to/path/bin/
    clusterdb.exe   droplang.exe   oid2name.exe        pg_isready.exe      reindexdb.exe
    createdb.exe    dropuser.exe   pg_basebackup.exe   pg_receivexlog.exe  vacuumdb.exe
    createlang.exe  ecpg.exe       pg_config.exe       pg_restore.exe      vacuumlo.exe
    createuser.exe  libpq.dll      pg_dump.exe         pgbench.exe
    dropdb.exe      oid2name.exe   pg_dumpall.exe      psql.exe
    $ ls /c/install/to/path/lib/
    libecpg.dll  libecpg_compat.dll  libpgcommon.lib  libpgtypes.dll  libpq.dll  postgres.lib
    libecpg.lib  libecpg_compat.lib  libpgport.lib    libpgtypes.lib  libpq.lib

This is going to simplify a bit more the life of Windows packagers who
have up to now needed custom scripts to install client-side things only.
So thanks MauMau!
