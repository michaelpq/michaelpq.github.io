---
author: Michael Paquier
lastmod: 2014-09-28
date: 2014-09-28 14:24:56+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-improved-logs-pg-dump
title: 'Postgres 9.5 feature highlight: Improved verbose logs in pg_dump'
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
- pg_dump
- log
- verbose
- relation
- schema

---

The following simple commit has improved the verbose logs of [pg\_dump]
(http://www.postgresql.org/docs/devel/static/app-pgdump.html) (the
ones that can be invocated with option -v and that are useful to keep a
log trace when using cron jobs kicking pg\_dump), by making the schema
names of the relations dumped show up as well:

    commit: 2bde29739d1e28f58e901b7e53057b8ddc0ec286
    author: Heikki Linnakangas <heikki.linnakangas@iki.fi>
    date: Tue, 26 Aug 2014 11:50:48 +0300
    Show schema names in pg_dump verbose output.

    Fabrízio de Royes Mello, reviewed by Michael Paquier

Let's take the case of a simple schema, with the same table name used
on two different schemas:

    =# CREATE SCHEMA foo1;
    CREATE SCHEMA
    =# CREATE SCHEMA foo2;
    CREATE SCHEMA
    =# CREATE TABLE foo1.dumped_table (a int);
    CREATE TABLE
    =# CREATE TABLE foo2.dumped_table (a int);
    CREATE TABLE

With pg\_dump bundled with 9.4 and older versions, each relation cannot
be really identified (think about the case of having multiple versions
of an application schema stored in the same database, but with different
schema names):

    $ pg_dump -v 2>&1 >/dev/null | grep dumped_table | grep TABLE
    pg_dump: creating TABLE dumped_table
    pg_dump: creating TABLE dumped_table
    pg_dump: setting owner and privileges for TABLE dumped_table
    pg_dump: setting owner and privileges for TABLE dumped_table
    pg_dump: setting owner and privileges for TABLE DATA dumped_table
    pg_dump: setting owner and privileges for TABLE DATA dumped_table

Now with 9.5, the following logs are showed.

    $ pg_dump -v 2>&1 >/dev/null | grep dumped_table | grep TABLE
    pg_dump: creating TABLE "foo1"."dumped_table"
    pg_dump: creating TABLE "foo2"."dumped_table"
    pg_dump: setting owner and privileges for TABLE "foo1"."dumped_table"
    pg_dump: setting owner and privileges for TABLE "foo2"."dumped_table"
    pg_dump: setting owner and privileges for TABLE DATA "foo1"."dumped_table"
    pg_dump: setting owner and privileges for TABLE DATA "foo2"."dumped_table"

Note as well the quotes put around the relation and schema names, making
this output more consistent with the other utilities in PostgreSQL. Also,
this is of course not only limited to relations, but to any object that
can be defined on a schema.
