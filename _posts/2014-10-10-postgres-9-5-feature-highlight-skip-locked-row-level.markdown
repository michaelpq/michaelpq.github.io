---
author: Michael Paquier
lastmod: 2014-10-10
date: 2014-10-10 07:10:44+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-skip-locked-row-level
title: 'Postgres 9.5 feature highlight - SKIP LOCKED for row-level locking'
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
- row
- level
- tuple
- security
- check
- user
- policy

---

SKIP LOCKED is a new feature associated with [row-level locking]
(http://www.postgresql.org/docs/devel/static/explicit-locking.html#LOCKING-ROWS)
that has been newly-introduced in PostgreSQL 9.5 by this commit:

    commit: df630b0dd5ea2de52972d456f5978a012436115e
    author: Alvaro Herrera <alvherre@alvh.no-ip.org>
    date: Tue, 7 Oct 2014 17:23:34 -0300
    Implement SKIP LOCKED for row-level locks

    This clause changes the behavior of SELECT locking clauses in the
    presence of locked rows: instead of causing a process to block waiting
    for the locks held by other processes (or raise an error, with NOWAIT),
    SKIP LOCKED makes the new reader skip over such rows.  While this is not
    appropriate behavior for general purposes, there are some cases in which
    it is useful, such as queue-like tables.

    Catalog version bumped because this patch changes the representation of
    stored rules.

    Reviewed by Craig Ringer (based on a previous attempt at an
    implementation by Simon Riggs, who also provided input on the syntax
    used in the current patch), David Rowley, and Álvaro Herrera.

    Author: Thomas Munro

Let's take for example the simple case of the following table that will
be locked:

    =# CREATE TABLE locked_table AS SELECT generate_series(1, 4) as id;
    SELECT 1

Now a session is taking a shared lock on the row created of locked\_table,
taking the lock within a transaction block ensures that it will still be
taken for the duration of the tests.

    =# BEGIN;
    BEGIN
    =# SELECT id FROM locked_table WHERE id = 1 FOR SHARE;
     id
    ----
      1
    (1 row)

Now, the shared lock prevents any update, delete or even exclusive lock from
being taken in parallel. Hence the following query will wait until the
transaction of previous session finishes. In this case this query is cancel
by the user (note that error message tells for which row this query was
waiting for):

    =# SELECT * FROM locked_table WHERE id = 1 FOR UPDATE;
    ^CCancel request sent
    ERROR:  57014: canceling statement due to user request
    CONTEXT:  while locking tuple (0,1) in relation "locked_table"
    LOCATION:  ProcessInterrupts, postgres.c:2966

There is already one way to bypass this wait phase, by using NOWAIT with the
lock taken to return an error instead of waiting if there is a conflict:

    =# SELECT * FROM locked_table WHERE id = 1 FOR UPDATE NOWAIT;
    ERROR:  55P03: could not obtain lock on row in relation "locked_table"
    LOCATION:  heap_lock_tuple, heapam.c:4542

And now shows up SKIP LOCKED, that can be used to bypass the rows locked when
querying them:

    =# SELECT * FROM locked_table ORDER BY id FOR UPDATE SKIP LOCKED;
     id
    ----
      2
      3
      4
    (3 rows)

Note that this makes the data taken actually inconsistent, but this new clause
finds its utility to reduce lock contention for example on queue tables where
the same rows are being access from multiple clients simultaneously.
