---
author: Michael Paquier
lastmod: 2014-06-15
date: 2014-06-15 13:07:29+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-gist-inet-datatype
title: 'Postgres 9.4 feature highlight - GiST operator class for inet and cidr datatypes'
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
- indexes
- gist
- inet
- cidr
---
Postgres 9.4 is adding a new in-core GiST operator class for the [inet and cidr]
(http://www.postgresql.org/docs/9.4/static/datatype-net-types.html#DATATYPE-INET)
datatypes. It has been introduced by this commit:

    commit f23a5630ebc797219b62797f566dec9f65090e03
    Author: Tom Lane <tgl@sss.pgh.pa.us>
    Date:   Tue Apr 8 15:46:14 2014 -0400

    Add an in-core GiST index opclass for inet/cidr types.

    This operator class can accelerate subnet/supernet tests as well as
    btree-equivalent ordered comparisons.  It also handles a new network
    operator inet && inet (overlaps, a/k/a "is supernet or subnet of"),
    which is expected to be useful in exclusion constraints.

    Ideally this opclass would be the default for GiST with inet/cidr data,
    but we can't mark it that way until we figure out how to do a more or
    less graceful transition from the current situation, in which the
    really-completely-bogus inet/cidr opclasses in contrib/btree_gist are
    marked as default.  Having the opclass in core and not default is better
    than not having it at all, though.

    Emre Hasegeli, reviewed by Andreas Karlsson, further hacking by me

Note that the default operator for this data type remains btree for
historical reasons and that the new GiST operator needs to be specified
as follows using inet_ops:

    =# CREATE TABLE inet_table (data inet);
    CREATE TABLE
    =# CREATE INDEX inet_btree ON inet_table(data);
    CREATE INDEX
    =# CREATE INDEX inet_gist ON inet_table USING gist (data inet_ops);
    CREATE INDEX
    =# \d inet_table
     Table "public.inet_table"
     Column | Type | Modifiers 
    --------+------+-----------
     data   | inet | 
    Indexes:
         "inet_btree" btree (data)
         "inet_gist" gist (data inet_ops)

By looking at [the documentation listing all the operators available for
those datatypes](http://www.postgresql.org/docs/9.4/static/functions-net.html)
(as well as at the commit log on top of this post), the major addition that
this feature brings is a new operator && to test if an inet address contains
of is contained by a second one. Here is what happened in 9.3 and older
versions because of the lack of operator:

    =# SELECT inet '145.127.4.84/24' && inet '145.127.4.81/24' as res;
    ERROR:  42883: operator does not exist: inet && inet
    LINE 1: SELECT inet '145.127.4.84/24' && inet '145.127.4.80/32';
                                          ^
    HINT:  No operator matches the given name and argument type(s). You might need to add explicit type casts.
    LOCATION:  op_error, parse_oper.c:722

And here is how the solution has evolved with 9.4:

    =# SELECT inet '145.127.4.84/24' && inet '145.127.4.81/24' as res;
     res 
    -----
     t
    (1 row)

A small thing perhaps, but always useful to know.
