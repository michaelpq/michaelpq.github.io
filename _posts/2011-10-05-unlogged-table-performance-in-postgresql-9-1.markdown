---
author: Michael Paquier
lastmod: 2011-10-05
date: 2011-10-05 07:20:06+00:00
layout: post
type: post
slug: unlogged-table-performance-in-postgresql-9-1
title: Unlogged table performance in postgresql 9.1
categories:
- PostgreSQL-2
tags:
- 9.1
- 9.2
- asynchronous
- commit
- crash
- performance
- pgbench
- postgresql
- recovery
- table
- unlogged
- wal
- write ahead log
---

This study is made with PostgreSQL 9.1.1, released a couple of days before this post is written.
Unlogged tables are a new performance feature of PostgreSQL 9.1, created by Robert Hass. So, by guessing from this feature name, those tables are not logged in the database system :). More precisely, those tables do not use at all WAL (Write ahead log) that insure a safe database crash.
Those tables are a good performance gain to contain data that do not especially need to survive from a crash, they are truncated automatically after a crash or unclean shutdown.
Unlogged tables are shared among sessions, and are not deleted when a session ends. Autovacuum runs on them.

So, in what cases could you use it.

  * On web applications, for session parameters
  * Data caching (Web page caching, why not?)
  * Application status, imagine that you add a on/off lock switch on your application that an admin could modify at will. This is not necessary at database server crash and could be reinitialized at a default value if necessary.
  * And many other things

In order to define an unlogged table, you need to use a new extension keyword called UNLOGGED (surprise!).
    CREATE UNLOGGED TABLE aa (a int, b int);

This is a performance feature, so let's see how much gain you could expect with pgbench.
Environment used is a 2.6GHz Dual core i5 with 4GB of memory.
PostgreSQL server has the following settings:

  * shared\_buffers = 1GB
  * synchronous\_commit = off
  * checkpoint\_segments = 32
  * checkpoint\_completion\_target = 0.9

By default, pgbench is not able to use unlogged tables, so the code has been a bit modified to change all DDL definitions when tests are made on unlogged tables.
First, pgbench can be found in contrib directory. Once installed, you can initialize with pgbench with the following commands:

    createdb benchtest
    pgbench -i -s $SCALE_FACTOR benchtest`

SCALE\_FACTOR is used at 10 and 100 for this study. Roughly, it represents the number of tables. I do not advice using default value to avoid lock contention.

Then you can launch pgbench with commands like:

    pgbench -c $CLIENT_NUM -T 300 benchtest

CLIENT\_NUM is the number of clients connected to the database. Here we use successively 1, 24 and 48.
For each configuration, 5 tests of a duration of 5 minutes are made. The lowest and highest values are not taken into account, and the average based on the other values is calculated.

Here are the results found in TPS (transaction/second).

| Clients | Scale factor | Normal tables | Unlogged tables | Gain (Unlogged - Perm)/avg(Unlogged, Perm) |
| ------- | ------------ | ------------- | --------------- | ----------------------------------------- |
| 1 | 10 | 561.63 | 632.55 | 11.87% |
| 24 | 10 | 1419.30 | 1678.23 | 16.71% |
| 48 | 10 | 1323.78 | 1555.40 | 16.08% |
| 1 | 100 | 510.25 | 436.87 | 13.22% |
| 24 | 100 | 1252.38 | 1493.44 | 17.55% |
| 48 | 100 | 1260.09 | 1462.92 | 14.89% |

So in short, in the environment tested unlogged tables have shown an increase of output by 13~17%.
