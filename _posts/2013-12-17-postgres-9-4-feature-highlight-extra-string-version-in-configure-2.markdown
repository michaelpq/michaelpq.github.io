---
author: Michael Paquier
comments: true
date: 2013-12-17 07:11:18+00:00
layout: post
slug: postgres-9-4-feature-highlight-extra-string-version-in-configure-2
title: 'Postgres 9.4 feature highlight: extra string version in configure'
wordpress_id: 2006
categories:
- PostgreSQL-2
tags:
- 9.4
- application
- build
- cloud
- configure
- custom
- database
- development
- pg_version
- pg_version_num
- postgres
- postgresql
- string
- version
---
Today's post presents a small utility that has been added during the latest commit fest of Postgres: the possibility to add some custom information in version stream during a server build. It has been introduced by this commit.

    Author: Peter Eisentraut Date: Thu Dec 12 21:53:21 2013 -0500
 
    configure: Allow adding a custom string to PG_VERSION
 
    This can be used to mark custom built binaries with an extra version
    string such as a git describe identifier or distribution package release
    version.
 
    From: Oskari Saarenmaa

This new option needs to be specified when running [configure](http://www.postgresql.org/docs/devel/static/install-procedure.html) with a new option called --with-extra-version. This is particularly interesting when creating custom builds of PostgreSQL without modifying the core code. I can imagine easily that there are many custom scripts in the wild using many sed commands to do exactly the same work, so this will help in simplifying a bit such mechanisms (personal note: some of my scripts do that actually).

Once used, this will generate new versions strings for the variables PG\_VERSION and PG\_VERSION\_STR that are completed with the custom string, using it as a suffix to the existing version identifier. Here is how the version string is generated with a simple example:

    $ ./configure --with-extra-version=foo
    [... stuff ...]
    $ find . -name pg_config.h | xargs grep "foo"
    #define PG_VERSION "9.4develfoo"
    #define PG_VERSION_STR "PostgreSQL 9.4develfoo compiled with blabla"

It is however better to use a separator at the beginning of the extra string with for example something like that:

    ./configure --with-extra-version=-`git rev-parse --short HEAD`

This produces the following output, useful when tracking easily a build based on a given SHA1 git commit.

    #define PG_VERSION "9.4devel-60eea37"
    #define PG_VERSION_STR "PostgreSQL 9.4devel-60eea37 compiled with blabla"

Or you can do as well some more fancy things like that:

    ./configure --with-extra-version=" (My own cool stuff v0.1)"
    #define PG_VERSION "9.4devel (My own cool stuff v0.1)"
    #define PG_VERSION_STR "PostgreSQL 9.4devel (My own cool stuff v0.1) blabla"

Finally note that PG\_VERSION\_STR and PG\_VERSION are used to reference the version number of all the binaries launched with --version.

    $ psql --version
    psql (PostgreSQL) 9.4develfoo
    $ createuser --version
    createuser (PostgreSQL) 9.4develfoo

As well as when querying version() on a server.

    $ psql -c "SELECT version()"
                  version
    ----------------------------------
     PostgreSQL 9.4develfoo on blabla
    (1 row)

Also, you need to be aware of the disadvantages of such customizations as well: some applications parsing the output of version() to determine the version of a Postgres server might create unexpected errors.
