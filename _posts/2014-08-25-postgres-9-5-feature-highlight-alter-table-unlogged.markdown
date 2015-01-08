---
author: Michael Paquier
lastmod: 2014-08-25
date: 2014-08-25 06:17:56+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-alter-table-unlogged
title: 'Postgres 9.5 feature highlight: ALTER TABLE .. SET LOGGED / UNLOGGED'
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
- unlogged
- table
- reverse
- permanent
- WAL
- crash
- safe
- switch

---

Introduced in PostgreSQL 9.1, an [unlogged table]
(http://www.postgresql.org/docs/devel/static/sql-createtable.html) offers
the possibility to create a table whose definition is permanent on server,
but its content is not [WAL-logged
](http://www.postgresql.org/docs/9.1/static/wal.html)
making it not crash-safe, with data that cannot be accessed on a read-only
stannby continuously replaying WAL at recovery. Postgres 9.5 offers an
improvement in this area with the possibility to switch the persistency of
an unlogged to permanent and vice-versa:

    commit: f41872d0c1239d36ab03393c39ec0b70e9ee2a3c
    author: Alvaro Herrera <alvherre@alvh.no-ip.org>
    date: Fri, 22 Aug 2014 14:27:00 -0400
    Implement ALTER TABLE .. SET LOGGED / UNLOGGED

    This enables changing permanent (logged) tables to unlogged and
    vice-versa.

    (Docs for ALTER TABLE / SET TABLESPACE got shuffled in an order that
    hopefully makes more sense than the original.)

    Author: Fabrízio de Royes Mello
    Reviewed by: Christoph Berg, Andres Freund, Thom Brown
    Some tweaking by Álvaro Herrera

Something to be careful: running this command actually rewrites entirely
the table, generating new WAL in consequence, while taking an exclusive
lock on it. Hence the table cannot be accessed by other operations during
the rewrite in order to recreate a new relfilenode for the relation whose
persistence is changed.

Now, this command is rather simple to use. Let's use an unlogged table that
has some data.

    =# CREATE UNLOGGED TABLE tab_test
	   AS SELECT generate_series(1,5) AS a;
    SELECT 5
    =# SELECT oid,relfilenode FROM pg_class where oid = 'aa'::regclass;
      oid  | relfilenode
    -------+-------------
     16391 |       16397
    (1 row)

This data cannot be requested on a standby and any query on it will fail
like that:

    =# SELECT pg_is_in_recovery();
     pg_is_in_recovery
    -------------------
     t
    (1 row)
    =# SELECT * FROM tab_test;
    ERROR:  0A000: cannot access temporary or unlogged relations during recovery
    LOCATION:  get_relation_info, plancat.c:104

Now running the command [ALTER TABLE .. SET LOGGED]
(http://www.postgresql.org/docs/devel/static/sql-altertable.html) results
in the relation to become persistent:

    =# ALTER TABLE tab_test SET LOGGED;
    ALTER TABLE
    =# SELECT oid,relfilenode FROM pg_class where oid = 'aa'::regclass;
      oid  | relfilenode
    -------+-------------
     16391 |       16397
    (1 row)

And its data becomes as well available in WAL:

    =# SELECT pg_is_in_recovery();
     pg_is_in_recovery
    -------------------
     t
    (1 row)
    =# select count(*) from tab_test;
     count
    -------
     5
    (1 row)

The reverse operation is possible as well with UNLOGGED. A last thing to
note: ALTER TABLE returns success and hte operation is ignored if LOGGED
is run on a relation already permanent and if UNLOGGED is run on a relation
already unlogged.
