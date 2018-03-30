---
author: Michael Paquier
lastmod: 2016-11-20
date: 2016-11-20 08:40:41+00:00
layout: post
type: post
slug: postgres-10-pg-basebackup
title: 'Postgres 10 highlight - pg_basebackup improvements'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 10
- pg_basebackup

---

Lately three improvements and behavior changes have been added to
pg\_basebackup that will be part of Postgres 10.

The first one relates to the state of an on-disk backup folder on failure.
In short, in the event of a failure, pg\_basebackup will remove an folders
it has created when processing. This has been introduced by
[commit 9083353](http:// http://git.postgresql.org/pg/commitdiff/9083353).

There are a couple of things to be aware of when using this feature
though:

  * When pg\_basebackup is stopped with a signal, no cleanup action
  is taken.
  * The format used, either plain or tar, does not matter, cleanup
  actions are taken in the target directory.
  * When including WAL segments in the backup directory, cleanup
  actions are taken as well.

In order to get the pre-10 behavior, one can specified the new option
--no-clean to keep around the folders and contents created. This is
mainly useful for test and development purposes, as was the pre-10
behavior. And the new default removes the need to remove manually
the target directory used, that very contains a cluster data in a
corrupted state anyway, still keeping it around may be useful for
debugging.

A second thing to be aware of is that support for --xlog-stream=stream
has been added for the tar mode, support added by
[commit 56c7d8d](http:// http://git.postgresql.org/pg/commitdiff/56c7d8d).
So commands of the following type are in Postgres 10 not a problem anymore:

    pg_basebackup -D $PGDATA --xlog-method=stream --format=t

As the WAL streaming happens in a different process forked from the
main one in charge of taking the base backup, this creates a second
tar file named pg\_wal.tar. Hence the base backup would finish with
a tar file for each tablespace, as well as the contents to save into
the folder pg\_wal/ (pg\_xlog/ for pre-10 clusters). That's the main
point to be aware of: when restoring a backup from a tar-formatted
method, the contents of the newly-created tar file need to be of
course untar'ed, but more importantly copied into their correct place.

A third thing that has been improved in pg\_basebackup is the handling
of a couple of folders that are now excluded from a base backup. This
has been added by
[commit 6ad8ac6](http:// http://git.postgresql.org/pg/commitdiff/6ad8ac6).
Here is the list of the folders whose symlinks in the source server
are changed into empty folders in the base backup:

  * pg\_notify/ for NOTIFY/LISTEN contents.
  * pg\_serial/ for serializable transaction commits.
  * pg\_snapshots/ for external snapshot data.
  * pg\_stat\_tmp/, default path for temporary statistics.
  * pg\_subtrans/ for sub-transaction status data.

Note that the pre-10 behavior is actually failing to handle symlinks
of those paths, so be aware of the limitation in this case. For example
pg\_stat\_tmp/ is the default setting for hte temporary statistics
directory though instead of specifying an absolute path in postgresql.conf
some users prefer keeping the default value and use instead a symlink to
a different destination. Also an important thing to notice is that pg\_xlog
(or pg\_wal for version 10), as well as pg\_replslot/ are already included
as empty directories in a base backup if they are present as symlinks in
the source server.

Since all those features have been committed, there are no other
developments in the plans for Postgres 10 at the moment this post is
written. There is of course no guarantee than nothing else will happen
but the current state of things gives a good image of what pg\_basebackup
will be able to do when the next major version of Postgres is released.
