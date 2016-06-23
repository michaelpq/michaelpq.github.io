---
author: Michael Paquier
lastmod: 2013-01-29
date: 2013-01-29 02:59:59+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-for-key-share-and-for-no-key-update
title: 'Postgres 9.3 feature highlight - FOR KEY SHARE and FOR NO KEY UPDATE'
categories:
- PostgreSQL-2
tags:
- '9.3'
- contention
- database
- delete
- dml
- feature
- for key
- for share
- for update
- highlight
- key
- lock
- open source
- performance
- postgres
- postgresql
- trigger
- update
---
Prior to PostgreSQL 9.3, there are two levels of locks allowing to control DML
operations on a given set of rows for a transaction by using SELECT FOR SHARE
and FOR UPDATE. Such locks taken on rows in a transaction block allow blocking
INSERT/DELETE/UPDATE on those rows.
There is also a protocol between those lock levels. FOR UPDATE is equivalent
to an exclusive lock on the row selected, meaning that no other backend can
take a FOR UPDATE lock on the same row and waits until the other other
transaction finishes. FOR SHARE means that all the other backends can take a
FOR SHARE lock on those rows. No FOR UPDATE locks can be taken on rows already
locked with FOR SHARE. It is also possible to use the NOWAIT option, making
the server return an error if there is a wait situation.

PostgreSQL 9.3 introduces two new levels of locks: FOR KEY SHARE and FOR NO
KEY UPDATE. This feature has been committed thanks to the perseverance of
Alvaro Herrera after two years of effort. Really congratulations to
[Alvaro](https://twitter.com/alvherre)!

    commit 0ac5ad5134f2769ccbaefec73844f8504c4d6182
    Author: Alvaro Herrera <alvherre@alvh.no-ip.org>
    Date:   Wed Jan 23 12:04:59 2013 -0300
    
    Improve concurrency of foreign key locking
    
    This patch introduces two additional lock modes for tuples: "SELECT FOR
    KEY SHARE" and "SELECT FOR NO KEY UPDATE".  These don't block each
    other, in contrast with already existing "SELECT FOR SHARE" and "SELECT
    FOR UPDATE".  UPDATE commands that do not modify the values stored in
    the columns that are part of the key of the tuple now grab a SELECT FOR
    NO KEY UPDATE lock on the tuple, allowing them to proceed concurrently
    with tuple locks of the FOR KEY SHARE variety.
    
    Foreign key triggers now use FOR KEY SHARE instead of FOR SHARE; this
    means the concurrency improvement applies to them, which is the whole
    point of this patch.

The main point of this feature is to reduce lock contention for foreign key
triggers, as now those ones use FOR KEY SHARE instead of FOR SHARE. Also,
UPDATE commands that do not update columns related to the key of the tuple
now take now a FOR NO KEY UPDATE, explaining the name of the lock. With
this level of locking, UPDATE queries that do not involve columns of the
tuple key can perform concurrently.

Honestly, with now 4 levels of locks, it is becoming complicated to remember
which operation blocks or allows the other on the same tuple. So let's make
a couple of tests to determine what blocks what with a simple table with
some data:

    postgres=# CREATE TABLE aa AS SELECT 1 AS a;
    SELECT 1

The test scenario is pretty simple: two client sessions trying to take a
lock on the same tuple. Session 1 launches its commands first, then session
2, the goal being to see if session 2 takes the lock or waits for it.
Session 1:

    BEGIN;
    SELECT * FROM aa FOR $LOCK;

Then session 2 does that

    SELECT * FROM aa FOR $LOCK;

$LOCK can be either FOR SHARE, FOR UPDATE, FOR NO KEY UPDATE or FOR KEY SHARE. 

Here are the results:

 Locks          | UPDATE | NO KEY UPDATE | SHARE | KEY SHARE
---------------|--------|---------------|-------|-----------
UPDATE          |  Waits |         Waits | Waits |     Waits
NO KEY UPDATE   |  Waits |         Waits | Waits |        OK
SHARE           |  Waits |         Waits |    OK |        OK
KEY SHARE       |  Waits |            OK |    OK |        OK

I hope this table helps. Have fun.
