---
author: Michael Paquier
lastmod: 2014-08-11
date: 2014-08-11 08:27:27+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-pg-receivexlog-fsync
title: 'Postgres 9.5 feature highlight - pg_receivexlog improvements with fsync'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.5
- wal
- pg_receivexlog

---

[pg_receivexlog](https://www.postgresql.org/docs/devel/static/app-pgreceivexlog.html)
is an in-core utility of Postgres able to recover WAL files through a stream
using the replication protocol. It is particularly useful when for example
using it to transfer some WAL files to a proxy node when standby node cannot
connect directly to a root node for whatever reason. The standby can then
replay the WAL files obtained. The reliability of this utility has been
improved in Postgres 9.5 with the following commit:

    commit: 3dad73e71f08abd86564d5090a58ca71740e07e0
    author: Fujii Masao <fujii@postgresql.org>
    date: Fri, 8 Aug 2014 16:50:54 +0900
    Add -F option to pg_receivexlog, for specifying fsync interval.

    This allows us to specify the maximum time to issue fsync to ensure
    the received WAL file is safely flushed to disk. Without this,
    pg_receivexlog always flushes WAL file only when it's closed and
    which can cause WAL data to be lost at the event of a crash.

    Furuya Osamu, heavily modified by me.

Thanks to the addition of a new option called -F/--fsync-interval, user can
now control the interval of time between which WAL records are flushed to disk
with fsync calls.

The default value, 0, makes flush occur only when a WAL file is closed. This
is the same flush strategy as in the previous versions of this utility (since
9.2 precisely).

On the contrary, specifying -1 will make sure that WAL data is flushed as soon
as possible, in this case at the moment when WAL data is available.

Now, using this option is rather simple:

    pg_receivexlog -v -D /path/to/raw_wal/ -F -1 # For maximum flush
    pg_receivexlog -v -D /path/to/raw_wal/ -F 0  # For default
    pg_receivexlog -v -D raw_wal/ -F 10          # For interval of 10s

The level of information printed in verbose mode has not changed as well,
so you can continue to rely on that as before.

    $ pg_receivexlog -D raw_wal/ -v
    pg_receivexlog: starting log streaming at 0/4D000000 (timeline 1)
    pg_receivexlog: finished segment at 0/4E000000 (timeline 1)
    pg_receivexlog: finished segment at 0/4F000000 (timeline 1)
    pg_receivexlog: finished segment at 0/50000000 (timeline 1)
    pg_receivexlog: finished segment at 0/51000000 (timeline 1)

An important thing to note is that even if there is more control in the way
WAL files are flushed, on the server side pg\_receivexlog reports back to
server the same kind of information as in previous versions, so there is
still noflush position even if it actually flushes data.

    =# SELECT application_name, write_location, flush_location, sync_state
       FROM pg_stat_replication;
      application_name | write_location | flush_location | sync_state
     ------------------+----------------+----------------+------------
      pg_receivexlog   | 0/4DF3D900     | null           | async
     (1 row)

Well, this may be a subject for a new patch.
