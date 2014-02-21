---
author: Michael Paquier
comments: true
lastmod: 2013-05-09
date: 2013-05-09 06:14:47+00:00
layout: post
type: post
slug: looking-at-the-roots-of-postgres-configure-processing
title: 'Looking at the roots of Postgres: configure processing'
categories:
- PostgreSQL-2
tags:
- autoconf
- basic
- configure
- database
- db
- dependency
- environment
- library
- open source
- operating system
- os
- package
- postgres
- processing
- root
---

Before launching make for a raw build, Postgres does some preprocessing with configure to setup the installation based on the environment and the different options given by user. If you don't do that before trying a make, your build will fail with a critical hit of this type:

    $ make

You need to run the 'configure' program first. See the file

    INSTALL' for installation instructions.
    make: *** [all] Error 1

It is important to get familiar with this way of doing before actually working or developing Postgres, so be sure to go through the notes of this post to learn one thing or two, or even complete those notes with comments at the bottom.

This process is launched with ./configure, located at the root of the code path (it can even be called outside of code folder in the case of a vpath installation) and generated directly from configure.in using autoconf. A couple of scripts located in config/ containing additional methods not in autoconf are also used when generating ./configure from ./configure.in for many things:

  * Check presence of necessary library dependencies, some of them being optional (documentation) and others mandatory as core process need them (flex, bison)
  * Check availability of some languages (perl.m4, python.m4)
  * Test C-related functionalities (c-compiler.m4, c-library.m4)
  * etc.

Note that those files are included through ./aclocal.m4 like that:

    m4_include([config/c-compiler.m4])`
    ./aclocal.m4 is included itself automatically by autoconf as default.

If you are a PostgreSQL developer, you might at some point create a fork of Postgres for a private project. In this case, you should definitely modify your project to be a maximum consistent with Postgres itself in order to facilitate merges with future versions. The preprocessing Postgres uses has few chances to change but it usually includes fixes that may be platform dependent, so be sure to fetch the fixes when they are here. Here are also some advices about how you should manage a fork regarding configure:

  * Modify in priority configure.in and not configure. Generate configure based on your modifications of configure.in.
  * When extra preprocessing is needed, add your own m4 procedures in config/ in separate files, except if they overlap with existing checks, so as if a fix happens on Postgres itself you will be able to at least detect easily if there is a conflict with what your own stuff.
  * Declare additional m4 files in ./aclocal.m4
  * Similarly, do not forget to update Makefile.global.in when adding some new variables, and use them!

Here is a short example of how you could add your own .in file with some code dedicated to configure.in understandable by autoconf.

    # Some initialization
    AC_INIT([mypgfork], [1.0devel], [joe@example.com])
    AC_CONFIG_AUX_DIR(config)
    # Setup a default prefix
    AC_PREFIX_DEFAULT(/usr/local/psql)
    
    # Addition of my own customized file
    AC_CONFIG_FILES([foo.cfg.in])
    
    # Option to enforce optimize to a wanted flag
    PGAC_ARG_BOOL(enable, optimize, no,
            [build with optimize symbol (-O2)])
    
    # supply -g if --enable-super-debug
    if test "$enable_optimize" = yes; then
        CFLAGS="-O2"
    fi
    
    # Substitute CFLAGS value in .in files
    AC_SUBST(CFLAGS)
    
    # Generate the output to files
    AC_OUTPUT

In this case a file called foo.cfg *is* generated... Feel free to play with this piece of code btw.

For a vanilla Postgres build, two files that are used for code make and installation are generated: src/Makefile.global.in (containing all the variables that are environment-dependent as well as all the configuration parameters that user has set when launching ./configure) and GNUMakefile.in.

When generating Postgres from raw code, there are some options in ./configure you should absolutely know about if you are a developer:

  * --prefix to define the folder where library and binaries will be installed (bin, share, lib, include).
  * --enable-cassert, to enable assertions inside a build (avoid that for a production build, this option is good only or development).
  * --enable-debug, making the code to compile with -g in CFLAGS, the default being -O2 for production builds.
  * --enable-depend, to enable automatic dependency tracking, useful to recompile all the objects affected by a header modification.

There are also some options that you might need if you develop an application based on Postgres:

  * --with-perl, to enable PL/Perl on server side
  * --with-python, to enable PL/Python on server side
  * --with-blocksize, defining the default block size used by table pages, default begin 8kB. Note that using binaries compiled with a given block size is not compatible with a existing server that has been initialized with a different block size.

Do not forget to have a look at all the options available [here](http://www.postgresql.org/docs/devel/static/install-procedure.html), configure might have many things that remained hidden to you until now.
