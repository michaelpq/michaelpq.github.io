---
author: Michael Paquier
comments: true
lastmod: 2013-12-09
date: 2013-12-09 04:01:32+00:00
layout: post
type: post
slug: about-regression-tests-with-postgres-plug-in-modules
title: 'About regression tests with Postgres plug-in modules'
categories:
- PostgreSQL-2
tags:
- bash
- check
- data
- database
- extension
- fdw
- hook
- installcheck
- module
- open source
- plug-in
- postgres
- postgresql
- production
- regression
- script
- storage
- test
---
PostgreSQL is made to be pluggable. With many types of plug-in structures available directly in core that make the development of external tools or even modules that can be directly be uploaded in a server with an untouched core code, there are many ways for a developer to develop a solution with things like [hooks](http://wiki.postgresql.org/images/e/e3/Hooks_in_postgresql.pdf), [foreign data wrappers](http://wiki.postgresql.org/wiki/Foreign_data_wrappers), [background workers](http://www.postgresql.org/docs/9.3/static/bgworker.html), custom data types, (index) operators, functions, aggregates that can be loaded through [extensions](http://www.postgresql.org/docs/9.1/static/sql-createextension.html) or defined as they are.

A developer can do many things, as well as he can break many things easily, so providing detailed documentation as well as easy ways to test if the module works as intended on perhaps many platforms is an essential part of the development work if a module is aimed for production. Once developed, those tests are then automatically run periodically in a way similar to what PostgreSQL buildfarm does on many platforms, with main focus on PostgreSQL core with regression and isolation tests and its contribution modules. There is nothing magic in that, providing a sane test environment (on platforms that are claimed as supported) is a normal process to ensure the quality and robustness of a product.

After this (kind-of-long) digression... Let's move to the heart of the topic of this post... Developers of PostgreSQL modules need to know that PostgreSQL provides a structure, called PGXS, to develop extensions, and that build and/or installation of a module can be controlled through its Makefile by passing some dedicated variables whose list can be found here.

For example, providing some documentation can be done with the flag DOCS:

    DOCS = mydoc1.txt mydoc2.txt

And this will install all the documentation in a dedicated path $PGINSTALL/share/doc/$MODULEDIR, MODULEDIR being extension if EXTENSION is set, or contrib if not.

Regression tests are as well-covered in this build infrastructure. When developing an extension and providing regression tests for it is simple. The input files need to be located in sql/ from the root directory of the extension. Output files need to be called with the same name as the input files, with the suffix .out, and need to be located in expected/. Once "make check" or "make installcheck" are run, the results are located in results. In case there are any diffs they are saved in regression.diffs.

Regression tests need to be specified with the flag REGRESS in Makefile, without the file suffix (.sql for the input in sql/, .out for the output in expected). Multiple entries are possible as well.

An advice when you manage some extension code with git, always add those entries to .gitignore:

    # Regression output
    /regression.diffs
    /regression.out
    /results/

This might save from some unfortunate platform-dependent results pushed to a remote git repository. Everybody has ever done that... Just don't do it.

Using this infrastructure is enough when developing an extension that interacts with one single server and does not manipulate the server settings as they can directly rely on pg\_regress by having "make check" passing extension names to load on server with the option -load-extension. In the case of modules using hooks (use LOAD at the top of the input SQL script, passwordcheck has no regression tests but could use that) or custom objects, this is fine. However for modules that need to have more fundamental settings at the server level like for example external tools that interact with the server or manage cluster, or even background workers, this can be tricked in a way similar to what pg\_upgrade does with a custom "make check" that kicks a script doing the test.

This does not seem as elegant as using a list of SQLs defined with REGRESS, but you can do anything, like using another programming language for your tests, as long as you keep in mind that the test passes if it returns 0, or else it fails.

Another possibility when using scripts is to still use a sql/expected structure, but to invoke directly bash commands in the sql script with something of this type:

    \! bash command.bash
    \! bash command2.bash

Then the output result is simply the output of the bash scripts to be compared.

Here is for example what is being used for pg\_rewind, after some refactoring of its test code scripts:

    check: test.sh all
        # Use a remote connection with source server
        MAKE=$(MAKE) bindir=$(bindir) libdir=$(libdir) $(SHELL) $< --remote
        # Use a data folder as source server
        MAKE=$(MAKE) bindir=$(bindir) libdir=$(libdir) $(SHELL) $< --local

Also, there are a couple of things to remember when using this way of doing... And here are some of the essentials.  

### Exit immediately when an error happens ###

Simply by using that at the top of your script:

    set -e


### Dynamic calculation of listening server port ####

Like pg\_regress, check if a port is already in use when creating a new server, something like...

    while psql -X postgres -p $PORT
    do
      NEWPORT=`expr $PORT + 1`
    done

### Environment variables ###

Unsetting some environment variables can resolve problems where connection occurs to the wrong server.

    unset PGDATABASE
    unset PGUSER
    unset PGHOST
    # etc.

This could be particularly useful to things like foreign data wrappers or background workers, just be aware that the maintenance cost becomes relatively heavy...
