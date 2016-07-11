---
author: Michael Paquier
lastmod: 2016-07-11
date: 2016-07-11 06:40:13+00:00
layout: post
type: post
slug: postgres-9-6-feature-highlight-pg-blocking-pids
title: 'Postgres 9.6 feature highlight - pg_blocking_pids'
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
- pid
- session
- block
- locks
- information
- join

---

pg\_blocking\_pids is one of those things that makes the life of analysis
tasks easier in Postgres. It has been introduced in 9.6 with the following
commit:

    commit: 52f5d578d6c29bf254e93c69043b817d4047ca67
    author: Tom Lane <tgl@sss.pgh.pa.us>
    date: Mon, 22 Feb 2016 14:31:43 -0500
    Create a function to reliably identify which sessions block which others.

    This patch introduces "pg_blocking_pids(int) returns int[]", which returns
    the PIDs of any sessions that are blocking the session with the given PID.
    Historically people have obtained such information using a self-join on
    the pg_locks view, but it's unreasonably tedious to do it that way with any
    modicum of correctness, and the addition of parallel queries has pretty
    much broken that approach altogether.  (Given some more columns in the view
    than there are today, you could imagine handling parallel-query cases with
    a 4-way join; but ugh.)

    [...]

You can refer to the
[commit text](http://git.postgresql.org/pg/commitdiff/52f5d578d6c29bf254e93c69043b817d4047ca67)
in full to get more details regarding why this function is better than a
join on the system catalogs pg\_locks (self join with one portion being the
waiter, and the other the holder, doing field-by-field comparisons), from which
is a short summary:

  * Better understanding of which lock mode blocks the other.
  * When multiple sessions are queuing to wait for a lock, only the one
  at the head is reported.
  * With parallel queries, all the PIDs of the parallel sessions are
  reported. Note that it is possible in this case that duplicated PIDs
  are reported here because for example multiple waiters are blocked by
  the same PID.

Note that the primary reason for its introduction is to simplify the isolation
testing facility that has been querying directly pg\_locks to get information
on the lock status between lock holders and waiters.

This function takes in input the PID of a session, and returns a set of PIDS
taking a lock that this session whose PID is used in input is waiting for.
So let's take an example, here is a session 1:

    =# CREATE TABLE tab_locked (a int);
    CREATE TABLE
    =# SELECT pg_backend_pid();
     pg_backend_pid
    ----------------
              68512
    (1 row)

And a session 2:

    =# BEGIN;
    BEGIN
    =# LOCK tab_locked IN ACCESS EXCLUSIVE MODE;
    LOCK TABLE
    =# SELECT pg_backend_pid();
     pg_backend_pid
    ----------------
              69223
    (1 row)

Finally by coming back to session 1, let's stuck it:

    =# INSERT INTO tab_locked VALUES (1);
    -- Hey I am stuck here

Then here comes pg\_blocking\_pids, one can fetch the following result,
reporting that the session taking the lock on table 'tab_locked' is blocking
the session trying to insert a tuple:

    =# SELECT pg_blocking_pids(68512);
     pg_blocking_pids
    ------------------
     {69223}
    (1 row)
  
... Which is not something complicated in itself, but it is surely going to
save a lot of typing or simplify a couple of extensions that have been doing
the same kind of work. Now, looking at the code in lockfuncs.c, this code is
actually far faster because it does directly lookups of the PGPROC entries
to gather the information regarding what the blocking information.

An even more interesting thing is the introduction of GetBlockerStatusData(),
which allows fetching the locking status data of a blocked PID to be able
to use that in a reporting function or any other facility. This is definitely
useful for people working on monitoring facilities aimed to track activity
of Postgres instances.
