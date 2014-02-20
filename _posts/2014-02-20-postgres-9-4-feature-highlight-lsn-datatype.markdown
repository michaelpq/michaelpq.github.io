---
author: Michael Paquier
comments: true
lastmod: 2014-02-20
date: 2014-02-20 07:21:12+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-lsn-datatype
title: 'Postgres 9.4 feature highlight: LSN datatype'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.4
- open source
- database
- development
- wal
- write ahead log
- lsn
- feature
- highlight
- datatype
- xlog
- log
- sequence
- number
- recovery
- bytes
- comparison
- operator
- content
- validation
---
In PostgreSQL terminology, an LSN (Log Sequence Number) is a 64-bit integer
used to determine a position in
[WAL](http://www.postgresql.org/docs/devel/static/wal-intro.html) (Write
ahead log), used to preserve data integrity. Internally in code, it is
managed as XLogRecPtr, a simple 64-bit integer. An LSN is represented with
two hexadecimal numbers of 8 digits each separated with "/". For example,
when looking on server what is the current position of WAL, you can do
something like that:

    =# SELECT pg_current_xlog_location();
     pg_current_xlog_location 
    --------------------------
     16/3002D50
    (1 row)

The first hexadecimal number corresponds to a logical xlog file with 256
segments of 16MB (total of 4096MB), incremented once segments are filled.
Segments are represented by the second hexadecimal number, as an offset of
the logical xlog file, and can go up to FFFFFFFF (FF000000 up to 9.3,
for a maximum of 4080MB for a single logical xlog file). Up to 9.3, all
the functions using LSN have been using as a substitute "text" to represent
an LSN number, so all the functions using LSN numbers had to transform
manual the output into a text before sending back the result to client.
9.4 improves the situation by using a [datatype dedicated to LSN]
(http://www.postgresql.org/docs/devel/static/datatype-pg-lsn.html),
introduced by this commit and called pg_lsn:

    commit 7d03a83f4d0736ba869fa6f93973f7623a27038a
    Author: Robert Haas <rhaas@postgresql.org>
    Date:   Wed Feb 19 08:35:23 2014 -0500

    Add a pg_lsn data type, to represent an LSN.

    Robert Haas and Michael Paquier

This has been completed later on by another patch switching a couple of
system functions to use this datatype. Here are the functions:

  * pg\_start\_backup
  * pg\_stop\_backup
  * pg\_switch\_xlog
  * pg\_create\_restore\_point
  * pg\_current\_xlog\_location
  * pg\_current\_xlog\_insert\_location
  * pg\_xlogfile\_name\_offset
  * pg\_xlogfile\_name
  * pg\_xlog\_location\_diff
  * pg\_last\_xlog\_receive\_location
  * pg\_last\_xlog\_replay\_location
  * pg\_create\_physical\_replication\_slot
  * pg\_get\_replication\_slots

Even if this is actually not backward-compatible, it is thought that this
should not have much consequence on user applications. Using a dedicated
datatype has as well several advantages:

  * Internal PostgreSQL code (extensions as well, I saw that many times)
does not need to manipulate anymore internally XLogRecPtr to change it
into an LSN.
  * Validation of LSN format (2 8-digit hexadecimal numbers separated by
"/") is now inside the data type itself.
  * External utilities can really take advantage of that.
  * Basic operators (=, !=, <, >, <=, >=, -) are included in the data type.

To finish, here are a couple of things doable now when manipulating LSNs,
like validation of LSN record format:

    =# SELECT 'G/0'::pg_lsn;
    ERROR:  22P02: invalid input syntax for type pg_lsn: "G/0"
    LINE 1: SELECT 'G/0'::pg_lsn;
                   ^
    LOCATION:  pg_lsn_in, pg_lsn.c:41

Or some simple arithmetic operations:

    =# SELECT pg_current_xlog_location() = pg_current_xlog_location() as diff;
     diff 
    ------
     t
    (1 row)
    =# SELECT pg_current_xlog_location() != pg_current_xlog_location() as diff;
     diff 
    ------
     f
    (1 row)

The operator "-" reduces the interest of pg\_xlog\_location\_diff, but it
needs to be kept for backward compatibility purposes (actually what this
does now is only calling pg\_lsn\_mi, the function of type pg_lsn called behind
operator "-"). Also, when using "-", the difference in bytes between two LSN
positions is calculated:

    =# \dfS+ pg_lsn_mi
    List of functions
    -[ RECORD 1 ]-------+-----------------------------
    Schema              | pg_catalog
    Name                | pg_lsn_mi
    Result data type    | numeric
    Argument data types | pg_lsn, pg_lsn
    Type                | normal
    Security            | invoker
    Volatility          | immutable
    Owner               | easter_egg
    Language            | internal
    Source code         | pg_lsn_mi
    Description         | implementation of - operator
    =# \x
    Expanded display (expanded) is off.
    =# SELECT pg_current_xlog_location() - '0/3000000' as diff;
     diff  
    -------
     12896
    (1 row)

This is going to make the code of some tools, like recovery/backup things,
much more simplified...
