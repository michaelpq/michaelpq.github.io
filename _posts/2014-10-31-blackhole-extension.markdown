---
author: Michael Paquier
lastmod: 2014-10-31
date: 2014-10-31 00:52:34+00:00
layout: post
type: post
slug: blackhole-extension
title: 'The Blackhole Extension'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- blackhole
- pg_plugins

---

Behind this eye-catching title is an [extension]
(http://www.postgresql.org/docs/devel/static/extend-extensions.html) called
blackhole that I implemented yesterday, tired of needing to always structure
a fresh extension when needing one (well copying one from Postgres contrib/
would be fine as well). Similarly to [blackhole_fdw]
(https://bitbucket.org/adunstan/blackhole_fdw/src) that is aimed to be an
extension for a foreign-data wrapper, blackhole is an extension wanted as
minimalistic as possible that can be used as a base template to develop a
Postgres extension in C.

When using it for your own extension, simply copy its code, create a new git
branch or whatever, and then replace the keyword blackhole by something you
want in the code. Note as well that the following files need to be renamed:

    blackhole--1.0.sql
    blackhole.c
    blackhole.control

Once installed in a vanilla state, this extension does not really do much, as
it only contains a C function called blackhole, able to do the following
non-fancy thing:

    =# \dx+ blackhole
    Objects in extension "blackhole"
      Object Description
    ----------------------
     function blackhole()
    (1 row)
    =# SELECT blackhole();
     blackhole
    -----------
     null
     (1 row)

Yes it simply returns a NULL string.

The code of this template is available [here]
(https://github.com/michaelpq/pg_plugins/tree/master/blackhole), or blackhole/
with the rest of a set of PostgreSQL plugins managed in the repository
[pg_plugins](https://github.com/michaelpq/pg_plugins). Hope that's useful
(or not). In case, if you have ideas to improve it, feel free to send a pull
request, but let's keep it as small as possible.

And Happy Halloween!
