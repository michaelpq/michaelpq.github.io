---
author: Michael Paquier
comments: true
lastmod: 2014-03-21
date: 2014-03-21 4:22:08+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-context-lock-waits
title: 'Postgres 9.4 feature highlight: Getting contexts of lock waits'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.4
- open source
- database
- development
- query
- transaction
- lock
- wait
- statement
- lock
- share
- exclusive
- context
- update
- information
- timeout
---
A new feature is showing up in PostgreSQL 9.4 allowing to get more information
about transaction lock waits and their circumstances. It has been introduced
by this commit:

    commit f88d4cfc9d417dac2ee41a8f5e593898e56fd2bd
    Author: Alvaro Herrera <alvherre@alvh.no-ip.org>
    Date:   Wed Mar 19 15:10:36 2014 -0300

    Setup error context callback for transaction lock waits

    With this in place, a session blocking behind another one because of
    tuple locks will get a context line mentioning the relation name, tuple
    TID, and operation being done on tuple.  For example:

    LOG:  process 11367 still waiting for ShareLock on transaction 717 after 1000.108 ms
    DETAIL:  Process holding the lock: 11366. Wait queue: 11367.
    CONTEXT:  while updating tuple (0,2) in relation "foo"
    STATEMENT:  UPDATE foo SET value = 3;

    Most usefully, the new line is displayed by log entries due to
    log_lock_waits, although of course it will be printed by any other log
    message as well.

    Author: Christian Kruse, some tweaks by Álvaro Herrera
    Reviewed-by: Amit Kapila, Andres Freund, Tom Lane, Robert Haas

Here is a short example of what happens with this new feature and the
following simple schema:

    =# CREATE aa (a int PRIMARY KEY, b int);
    CREATE TABLE
    =# INSERT INTO aa VALUES (1,1);
    INSERT 0 1

Now let's create a locking situation with a session 1 beginning a transaction
and updating the unique tuple of the table created previously.

    =# SELECT pg_backend_pid();
      pg_backend_pid 
     ----------------
              12452
    (1 row)
    =# BEGIN;
    BEGIN
    =# UPDATE aa SET b = 3 WHERE a = 1;
    UPDATE 1

The transaction is not over yet, and a row-level lock is taken on the tuple
updated.

    =# SELECT pid, locktype, mode, granted
       FROM pg_locks
       WHERE relation = 'aa'::regclass;
      pid  | locktype |       mode       | granted 
    -------+----------+------------------+---------
     12452 | relation | RowExclusiveLock | t
    (1 row)

Now, with the context callback, you can get details about the tuple on
which the lock is taken.

    =# begin;
    BEGIN
    =# SET statement_timeout TO '1s';
    SET
    =# UPDATE aa SET b = 4 WHERE a = 1;
    ERROR:  57014: canceling statement due to statement timeout
    CONTEXT:  while updating tuple (0,2) in relation "aa"
    LOCATION:  ProcessInterrupts, postgres.c:2912
    Time: 1000.765 ms

In this case, the information returned to identify the tuple being
locked is its TID or couple (relation page number, tuple number), called
as well ctid in TupleHeader, with the name of relation whose tuple is
locked. Now let's go back to session 1, and let's have a look at the tuple
that has been updated...

    =# COMMIT;
    COMMIT
    =# SELECT ctid, * FROM aa;
     ctid  | a | b 
    -------+---+---
     (0,2) | 1 | 3
    (1 row)

Another thing to know is that when log\_lock\_waits is enabled, this
more-than-useful context message is logged as well when locks waits more
than deadlock\_timeout, for a result similar to that:

    LOG:  process 12791 still waiting for ShareLock on transaction 1031 after 1001.052 ms
    DETAIL:  Process holding the lock: 12452. Wait queue: 12791.
    CONTEXT:  while updating tuple (0,2) in relation "aa"
    STATEMENT:  update aa set b = 4 where a = 1;

That's all folks.
