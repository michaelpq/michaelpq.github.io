---
author: Michael Paquier
lastmod: 2016-09-13
date: 2016-09-13 01:31:43+00:00
layout: post
type: post
slug: postgres-10-recovery-target-lsn
title: 'Postgres 10 highlight - recovery_target_lsn'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- 10
- feature
- highlight
- recovery
- target
- time
- lsn
- wal
- position

---

When performing point-in-time recovery, Postgres offers a variety of ways
to stop recovery, or WAL replay at a given point using different ways of
estimating the stop point:

  * Timestamp, with recovery\_target\_time.
  * Name, with recovery\_target\_name, which is a recovery target defined
  by a user with pg\_create\_restore\_point().
  * XID, with recovery\_target\_xid, a transaction ID that will make recovery
  go up to the point where the transaction where this ID was assigned has
  been committed.
  * 'immediate', which is a special case using recovery\_target = 'immediate'.
  Using that the recovery will stop when a consistent state has been reached
  by the server.

The replay position can as well be influenced by recovery\_target\_inclusive,
which is true by default (list of recovery parameters is
[here](https://www.postgresql.org/docs/devel/static/recovery-target-settings.html)).

Today's post is about a new recovery target type, that has been added in
Postgres 10 by this commit:

    commit: 35250b6ad7a8ece5cfe54c0316c180df19f36c13
    author: Simon Riggs <simon@2ndQuadrant.com>
    date: Sat, 3 Sep 2016 17:48:01 +0100
    New recovery target recovery_target_lsn

    Michael Paquier

An LSN (logical sequence number) is a position in a WAL stream, in short
a set of locations to know where a record is inserted, like '0/7000290'. So
with this new parameter what one is able to do is to set at a record-level
up to where recovery has to run. This is really helpful in many cases, but
the most common one is where for example WAL has been corrupted up to a given
record and a user would like to replay data as much as possible. With this
parameter there is no need to do a deep analysis of the WAL segments to look
at which transaction ID or time the target needs to be set: just setting
it to a record is fine. And one can even look at such a LSN position via the
SQL interface with for example pg\_current\_xlog\_location() that would give
the current LSN position that a server is using.

Let's take a small example with this cluster from which a base backup has
already been taken (important to be able to replay forward):

    =# CREATE TABLE data_to_recover(id int);
    CREATE TABLE
    =# INSERT INTO data_to_recover VALUES (generate_series(1, 100));
    INSERT 0 100
    =# SELECT pg_current_xlog_location();
     pg_current_xlog_location
    --------------------------
     0/3019838
    (1 row)

In this case the data inserted into the cluster has used WAL up to the LSN
position '0/152F080'. And now let's insert a bit more data:

    =# INSERT INTO data_to_recover VALUES (generate_series(101, 200));
    INSERT 0 100
    =# SELECT pg_current_xlog_location();
     pg_current_xlog_location
    --------------------------
     0/301B1B0
    (1 row)

And this adds a bit more data, consuming a couple of extra records. Now let's
do recovery up to where the first 100 tuples have been inserted, with a
recovery.conf containing the following (be sure that the last WAL segment has
been archived):

    recovery_target_lsn = '0/3019838'
    restore_command = 'cp /path/to/archive/%f %p'

After PITR completes, the logs will then show somthing like the following
entry (and then recovery pauses):

    LOG:  recovery stopping after WAL position (LSN) "0/3019838"

And by logging into this node, there are indeed only 100 tuples:

    =# SELECT count(*) FROM data_to_recover;
     count
    -------
       100
    (1 row)

Hopefully this will find its set of users, personally that is a powerful
tool.
