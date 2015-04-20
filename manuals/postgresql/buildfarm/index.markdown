---
author: Michael Paquier
date: 2013-04-12 04:15:36+00:00
layout: page
type: page
slug: buildfarm
title: 'PostgreSQL - Buildfarm'
tags:
- open source
- database
- postgres
- postgresql
- test
- machine
- server
- build
- farm
- buildfarm
- platform
- settings
---
Main resource is [here](http://wiki.postgresql.org/wiki/PostgreSQL_Buildfarm_Howto).
The important point is to check that all the scripts work with perl -cw
to be sure that no perl modules are missing.

Here are the packages to install on top of that:

    perl-lwp-protocol-https
    perl-digest-sha1
	perl-ipc-run
    ccache
    bison
    cronie
    flex
    gcc
    git-core
    make
    tcl
    libxslt

Check that build has necessary packages with command like that (simply copy-paste
that and don't think more, no python support here):

    ./configure --enable-cassert --enable-debug \
        --enable-nls --enable-integer-datetimes \
        --with-perl --with-tcl --with-krb5 \
        --with-includes=/usr/include/et --with-openssl
    make

Just to be sure that everything works fine, try a test build:

    ./run_build.pl --nosend --nostatus --verbose
