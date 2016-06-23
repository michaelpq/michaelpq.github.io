---
author: Michael Paquier
lastmod: 2015-12-02
date: 2015-12-02 12:25:45+00:00
layout: post
type: post
slug: postgres-9-6-feature-highlight-copy-dml-statements
title: 'Postgres 9.6 feature highlight - COPY and DML statements'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- 9.6
- feature
- highlight
- dml
- copy
- select
- values
- statement
- copy
- common
- table
- expression
- spec
- sql
- cte

---

A new set of queries that can be handled in [COPY]
(http://www.postgresql.org/docs/devel/static/sql-copy.html) statement (as
well as psql's \copy) has been added in PostgreSQL 9.6 by the following
commit:

    commit: 92e38182d7c8947a4ebbc1123b44f1245e232e85
    author: Teodor Sigaev <teodor@sigaev.ru>
    date: Fri, 27 Nov 2015 19:11:22 +0300
    COPY (INSERT/UPDATE/DELETE .. RETURNING ..)

    Attached is a patch for being able to do COPY (query) without a CTE.

    Author: Marko Tiikkaja

Common table expressions (WITH clause of a SELECT query or CTE), are a
feature present since PostgreSQL 8.4, those being able to be used as well
with DML statements (INSERT, UPDATE, DELETE) that include a RETURNING
statement since 9.1. Note that this last portion is not part of the SQL
specification, DML statements with RETURNING is a PostgreSQL extension
of the grammar.

Hence, thanks to the commit above, COPY TO has been extended similarly to
allow the use of DML queries directly (up to 9.5 VALUES as well as SELECT
are possible to use), simple examples being for example:

    =# CREATE TABLE tab_data (a int, b text);
    CREATE TABLE
    =# COPY (INSERT INTO tab_data VALUES (1, 'aa'), (2, 'bb') RETURNING a, b) TO stdout;
    1   aa
    2   bb
    =# COPY (UPDATE tab_data SET b = 'cc' WHERE a = 1 RETURNING *) TO stdout;
    1   cc
    =# COPY (DELETE FROM tab_data WHERE a = 2 RETURNING *) TO stdout;
    2   bb

Like a common table expression, the relation invoked cannot have an
underlying rule that would expand the query into multiple queries, like
an INSTEAD or an ALSO rule.

    =# CREATE RULE tab_nothing AS ON INSERT to tab_data DO INSTEAD NOTHING;
    CREATE RULE
    =# COPY (INSERT INTO tab_data VALUES (3, 'dd') RETURNING a, b) TO stdout;
    ERROR:  0A000: cannot perform INSERT RETURNING on relation "tab_data"
    HINT:  You need an unconditional ON INSERT DO INSTEAD rule with a RETURNING clause.
    LOCATION:  RewriteQuery, rewriteHandler.c:3353

Note that this grammar has the advantage to be more performant than using
a common table expression with a DML statement, hence queries like the
following one that could be written in Postgres 9.5 and prior versions will
prove to perform less than with the new grammar particularly if they work
on a large set of rows in one shot:

    =# COPY ( WITH data AS
        (INSERT INTO tab_data VALUES (4, 'ee'), (2, 'bb') RETURNING a, b)
       SELECT * FROM data) TO stdout;
    4   dd
    5   ee

In short, the SELECT used to fetch the return values of the DML statement
becomes unnecessary, making the operation faster.
