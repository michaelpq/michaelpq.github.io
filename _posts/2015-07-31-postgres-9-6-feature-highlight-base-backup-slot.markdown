---
author: Michael Paquier
lastmod: 2015-07-31
date: 2015-07-31 13:55:22+00:00
layout: post
type: post
slug: postgres-9-6-feature-highlight-base-backup-slot
title: 'Postgres 9.6 feature highlight - pg_basebackup and replication slots'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- replication
- wal
- 9.6
- slot

---

As the first post dedicated to the feature coverage of Postgres 9.6 which
is currently in active development, let's talk about the following commit:

    commit: 0dc848b0314d63188919f1ce943730eac684dccd
    author: Peter Eisentraut
    date: Tue, 28 Jul 2015 20:31:35 -0400
    pg_basebackup: Add --slot option

    This option specifies a replication slot for WAL streaming (-X stream),
    so that there can be continuous replication slot use between WAL
    streaming during the base backup and the start of regular streaming
    replication.

When taking a base backup with pg\_basebackup, one has surely already
experienced the problem that WAL files may be missing on the node from
where the backup has been taken when connecting for example a fresh standby
using this base backup after a certain delay. In such a case the standby node
would complain about the following error.

    FATAL:  could not receive data from WAL stream:
    ERROR:  requested WAL segment 000000010000000000000003 has already been removed

This can be easily avoided by having a WAL archive with a proper
restore\_command set in the standby's recovery.conf or by tuning
wal\_keep\_segments with a more or less appropriate number of segments
corresponding to the amount of data generated between the moment the
base backup has been started and the moment a standby node performing
streaming and using this base backup connects to its parent node. In the
former case, some users may not have a WAL archive set up (well they
normally should to be able to recover from only base backups). In the
later case, setting up wal\_keep\_segments is not an exact science, and
if the server faces a peak of activity you may still finish with a
missing WAL segments on the original node.

Well, this is where [physical replication slots]
(https://www.postgresql.org/docs/devel/static/warm-standby.html#STREAMING-REPLICATION-SLOTS)
are actually useful, because once created and enabled for a given client,
they are able to retain WAL segments as long at the slot's restart\_lsn
is not consumed by this client. Now, combined with pg\_basebackup, what
you actually get is the possibility to create a base backup and to ensure
that WAL segments will be present on the node from where the base backup
has been taken when combining it with the stream mode (-X stream). Hence
this makes sure that a given base backup does not become useless after
having taken it because of missing WAL segments lost until the moment the
base backup node is switched on. However be sure to have some kind of
monitoring to ensure that pg\_xlog on the original node does not get bloated
because of the WAL retained, and that the base backup is used becore
pg\_xlog partition or PGDATA gets full.

In order to use this feature, first create a physical replication slot
on the node from which the base backup will be taken:

    =# SELECT * FROM pg_create_physical_replication_slot('base_backup_slot');
        slot_name     | xlog_position
    ------------------+---------------
     base_backup_slot | null
    (1 row)
    =# SELECT slot_name, restart_lsn FROM pg_replication_slots;
        slot_name     | restart_lsn
    ------------------+-------------
     base_backup_slot | null
    (1 row)

Then invoke pg\_basebackup with the option --slot and the name of the slot
previously created:

    $ pg_basebackup -D base_backup --slot base_backup_slot -X stream

Once the base backup has been created the slot is activated and will begin
to retain the WAL needed for this base backup.

    $ psql -c "SELECT slot_name, restart_lsn FROM pg_replication_slots;"
        slot_name     | restart_lsn
    ------------------+-------------
     base_backup_slot | 0/2000000
    (1 row)

Note as well that when -R and --slot are used together to generate
automatically a recovery.conf file in the base backup,
primary\_slot\_name will be added with the slot name wanted, which is
handy as well.
