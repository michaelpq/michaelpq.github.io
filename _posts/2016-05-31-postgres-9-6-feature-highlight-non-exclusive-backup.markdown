---
author: Michael Paquier
lastmod: 2016-05-31
date: 2016-05-31 01:55:34+00:00
layout: post
type: post
slug: postgres-9-6-feature-highlight-non-exclusive-backup
title: 'Postgres 9.6 feature highlight - Non-exclusive base backups'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.6
- backup
- replication
- wal

---

pg\_start\_backup and pg\_stop\_backup, the two low-level functions of
PostgreSQL that can be used to take a base backup from an instance, have
been extended with a new option allowing to take what is called non-exclusive
backups. This feature is introduced in PostgreSQL 9.6 by the following commit:

    commit: 7117685461af50f50c03f43e6a622284c8d54694
    author: Magnus Hagander <magnus@hagander.net>
    date: Tue, 5 Apr 2016 20:03:49 +0200
    Implement backup API functions for non-exclusive backups

    Previously non-exclusive backups had to be done using the replication protocol
    and pg_basebackup. With this commit it's now possible to make them using
    pg_start_backup/pg_stop_backup as well, as long as the backup program can
    maintain a persistent connection to the database.

    Doing this, backup_label and tablespace_map are returned as results from
    pg_stop_backup() instead of being written to the data directory. This makes
    the server safe from a crash during an ongoing backup, which can be a problem
    with exclusive backups.

    The old syntax of the functions remain and work exactly as before, but since the
    new syntax is safer this should eventually be deprecated and removed.

    Only reference documentation is included. The main section on backup still needs
    to be rewritten to cover this, but since that is already scheduled for a separate
    large rewrite, it's not included in this patch.

    Reviewed by David Steele and Amit Kapila

The existing functions pg\_start\_backup and pg\_stop\_backup that are present
for ages in Postgres have a couple of limitations that have always been
disturbing for some users:

  * It is not possible to take multiple backups in parallel.
  * In case of a crash of the tool taking the backup, the server remains stuck
  in backup mode and needs some cleanup actions.
  * The backup\_label file being created in the data folder, it is not possible
  to make the difference between a server that crashed while a backup is taken
  and a cluster restored from a backup.

Some users are able to live with those problems, the application layer in
charge of the backups can take up extra cleanup actions in case of a backup
tool crash letting the cluster in an inconsistent state, or has a design that
assumes that no more than one backup can be taken.

Non-exclusive backups work in such a way that the backup\_label file and the
tablespace map file are not created in the data folder but are returned as
results of pg\_stop\_backup. In this case the backup tool is the one in
charge of writing both files in the backup taken. This has the advantage
to leverage all the problems that exclusive backups induce, at the cost
of a couple of things though:

  * The backup utility is in charge of doing some extra work to put the
  resulting base backup in a consistent state.
  * The connection to the backend needs to remain while the base backup
  is being taken. If the client disconnects while the backup is taken,
  it is aborted.

So, in order to control that, a third argument has been added to
pg\_start\_backup. Its default value is true, meaning that an exclusive
backup is taken, protecting all the existing backup tools:

    =# SELECT pg_start_backup('my_backup', true, false);
     pg_start_backup
    -----------------
     0/4000028
    (1 row)

Note also that pg\_stop\_backup uses now an extra argument to track if
it needs to stop an exclusive or a non-exclusive backup. With the backup
started previously, trying to stop an exclusive backup results in an
error:

    =# SELECT pg_stop_backup(true);
    ERROR:  55000: non-exclusive backup in progress
    HINT:  did you mean to use pg_stop_backup('f')?
    LOCATION:  pg_stop_backup_v2, xlogfuncs.c:230

Then let's stop it correctly, and the resulting fields are what is needed
to complete the backup.:

    =# SELECT * FROM pg_stop_backup(false);
    NOTICE:  00000: pg_stop_backup complete, all required WAL segments have been archived
    LOCATION:  do_pg_stop_backup, xlog.c:10569
        lsn    |                           labelfile                           | spcmapfile
    -----------+---------------------------------------------------------------+------------
     0/4000130 | START WAL LOCATION: 0/4000028 (file 000000010000000000000004)+|
               | CHECKPOINT LOCATION: 0/4000060                               +|
               | BACKUP METHOD: streamed                                      +|
               | BACKUP FROM: master                                          +|
               | START TIME: 2016-05-31 10:34:46 JST                          +|
               | LABEL: my_backup                                             +|
               |                                                               |
    (1 row)

The contents of "labelfile" need to be written as backup_label in the backup
taken while the contents of "spcmapfile" need to be written to tablespace_map.
Once the contents of those files is written, don't forget as well to flush
them to disk to prevent any potential loss caused by power failures for
example.
