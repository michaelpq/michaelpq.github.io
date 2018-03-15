---
author: Michael Paquier
lastmod: 2017-01-27
date: 2017-01-27 06:46:11+00:00
layout: post
type: post
slug: postgres-10-pgreceivexlog-compression
title: 'Postgres 10 highlight - Compression support in pg_receivexlog'
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
- pg_receivexlog
- wal
- write-ahead
- log
- receive
- stream
- replication
- reliability

---

One of my personal areas of work lately is in finding ways to improve
the user experience with WAL archiving and
[pg\_receivexlog](https://www.postgresql.org/docs/devel/static/app-pgreceivexlog.html).
A couple of experiments have been done, and one of them has finished as
a patch for upstream Postgres, in the shape of this commit:

    commit: cada1af31d769a6b607018d68894f2c879ff275f
    author: Magnus Hagander <magnus@hagander.net>
    date: Tue, 17 Jan 2017 12:10:26 +0100
    Add compression support to pg_receivexlog

    Author: Michael Paquier, review and small changes by me

Combined with replication slots, pg\_receivexlog is a nice way to ensure
that there is no hole in WAL segments. Compared to the archive\_command
itself, any failure handling in case of successive failures in archiving
a completed segment is easier as there is no need to tweak the parameter
of the archive\_command or the script used in the command itself to avoid
a bloat in pg\_xlog, resulting in a crash of Postgres if the partition
holding this folder gets full. Any failure handling can happen from a
remote position, and there is no need to have a superuser to do this work,
only a user with replication rights is enough to drop a slot and unlock
the situation. Note though that enforcing the recycling of past segments
requires a checkpoint to happen.

The commit above has added a way to compression on-the-fly with zlib WAL
records and to store them in .gz files, one for each segment. In those days
where disk is cheaper than CPU, compression is not a big deal for many
users and they are fine to afford more space to store the same amount of
history. However, in cases where Postgres is embedded in a system and
the amount of space allowed is controlled it may be a big deal to be able
to retain more history using the same amount of space, particularly knowing
that a WAL segment compressed with zlib is 3 to 4 times smaller.

The compression option can be activated with a new option switch called
\-\-compress, with which can be specified a number from 0 to 9, 0 meaning
no compression and 9 the highest level of compression. Note that level 9
is a huge CPU eater and that in an INSERT-only load the compression of
each segment may not be able to follow with the WAL generation, resulting
in pg\_receivexlog complaining that a segment it is requesting has already
been removed by a backend checkpoint or, if a replication slot is used,
resulting in a crash of the Postgres instance because of pg\_xlog getting
full.

   $ pg_receivexlog --compress=1 -D /path/to/logs/ --verbose
   pg_receivexlog: starting log streaming at 0/1000000 (timeline 1)
   pg_receivexlog: finished segment at 0/2000000 (timeline 1)
   pg_receivexlog: finished segment at 0/3000000 (timeline 1)
   [...]

And this generates many gzip-ready files.

   $ ls /path/to/logs/
   000000010000000000000001.gz
   000000010000000000000002.gz
   [...]
   000000010000000000000027.gz.partial

\-\-synchronous works as well with the compression support and makes sure
that the compressed files, even if not completed segments, are still
available. Backup and history files are compressed as well.

Another thing to note is that at startup phase, pg\_receivexlog scans
the directory it writes the WAL data into for existing segments that
are on it and decides based on that from which position it needs to
continue working on. The committed patch is smart enough to make a
difference between compressed, non-compressed, and even partial segments
so it is perfectly fine to mix compression or not and keep the same range
of segments saved.
