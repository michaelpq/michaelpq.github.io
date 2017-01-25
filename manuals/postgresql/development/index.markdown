---
author: Michael Paquier
date: 2014-03-09 14:14:18+00:00
layout: page
type: page
slug: development
title: PostgreSQL - Development
tags:
- postgres
- postgresql
- development
- documentation
- programming
- compilation

---

### Documentation

On most common Linux distributions, compiling the documentation requires the
following packages:

    docbook
    docbook2x
    docbook-dsssl
    docbook-xsl
    docbook-sgml
    openjade

With that, everything should be set up and ready to go, SGML catalogs are
as well set correctly via the package openjade. Using jade may result in
crashes, so avoid that at all costs.

### Code indentation

Here is a way to run pgindent on patches. First grab the list of type
definitions from the buildfarm:

    curl https://buildfarm.postgresql.org/cgi-bin/typedefs.pl -o my-typedefs.list

Then manually edit for example my-typedefs.list to add any new typedefs from
a patch, and finally run pgindent:

    pgindent --typedefs=my-typedefs.list target-files
