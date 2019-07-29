---
author: Michael Paquier
lastmod: 2019-07-29
date: 2019-07-29 07:54:51+00:00
layout: post
type: post
slug: postgres-12-replication-slot-copy
title: 'Postgres 12 highlight - Replication slot copy'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 12
- copy
- replication
- slot

---

Replication slots can be used in
[streaming replication](https://www.postgresql.org/docs/devel/warm-standby.html#STREAMING-REPLICATION-SLOTS),
with physical replication slots, and
[logical decoding](https://www.postgresql.org/docs/devel/logicaldecoding-explanation.html#LOGICALDECODING-REPLICATION-SLOTS),
with logical replication slots, to retain WAL in a more precise way than
[wal\_keep\_segments](https://www.postgresql.org/docs/devel/runtime-config-replication.html#RUNTIME-CONFIG-REPLICATION-SENDER)
so as past WAL segments are removed at checkpoint using the WAL position
a client consuming the slot sees fit.  A feature related to replication
slots has been committed to PostgreSQL 12:

    commit: 9f06d79ef831ffa333f908f6d3debdb654292414
    author: Alvaro Herrera <alvherre@alvh.no-ip.org>
    date: Fri, 5 Apr 2019 14:52:45 -0300
    Add facility to copy replication slots

    This allows the user to create duplicates of existing replication slots,
    either logical or physical, and even changing properties such as whether
    they are temporary or the output plugin used.

    There are multiple uses for this, such as initializing multiple replicas
    using the slot for one base backup; when doing investigation of logical
    replication issues; and to select a different output plugins.

    Author: Masahiko Sawada
    Reviewed-by: Michael Paquier, Andres Freund, Petr Jelinek
    Discussion: https://postgr.es/m/CAD21AoAm7XX8y_tOPP6j4Nzzch12FvA1wPqiO690RCk+uYVstg@mail.gmail.com

This introduces two new SQL functions adapted for each slot type:

  * pg\_copy\_logical\_replication\_slot
  * pg\_copy\_physical\_replication\_slot

By default [pg\_basebackup](https://www.postgresql.org/docs/devel/app-pgbasebackup.html)
uses a temporary replication slot to make sure that while transferring
the data of the main data folder the WAL segments necessary for recovery
from the beginning to the end of the backup are transferred properly,
and that the backup does not fail in the middle of processing.  In this
case the slot is called pg\_basebackup\_N where N is the PID of the
backend process running the replication connection.  However there are
cases where it makes sense to not use a temporary slot but a permanent
one, particularly when reusing a base backup as a standby with no WAL
archiving around, so as it is possible to keep WAL around for longer
without having a primary's checkpoint interfere with the recycling of
WAL segments.  One major take of course with replication slots is that
they require a closer monitoring of the local pg\_wal/ folder, as if
its partition gets full PostgreSQL would immediately stop.

In the case of a physical slot, a copy is useful when creating multiple
standbys from the same base backup.  As a replication slot can only
be consumed by one slot, it reduces the portability of a given base
backup, however it is possible to do the following:

  * Complete a base backup with pg_basebackup --slot using a permanent slot.
  * Create one or more copies of the original slot.
  * Use each slot for one standby, which release WAL at their own pace.

Another property of the copy functions is that it is possible to switch
a physical slot from temporary to permanent and vice-versa.  Here is for
example how to create a slot from a permanent one (controlled by the third
argument of the function) which retains WAL immediately (controlled by the
second argument).  The copy of the slot will mark the restart\_lsn of the
origin slot to be the same as the target:

    =# SELECT * FROM pg_create_physical_replication_slot('physical_slot_1', true, false);
        slot_name    |    lsn
    -----------------+-----------
     physical_slot_1 | 0/15F2A58
    (1 row)
    =# select * FROM pg_copy_physical_replication_slot('physical_slot_1', 'physical_slot_2');
        slot_name    | lsn
    -----------------+------
     physical_slot_2 | null
    (1 row)
    =# SELECT slot_name, restart_lsn FROM pg_replication_slots;
        slot_name    | restart_lsn
    -----------------+-------------
     physical_slot_1 | 0/15CF098
     physical_slot_2 | 0/15CF098
    (2 rows)

Note that it is not possible to copy a physical slot to become a logical
one, but that a slot can become temporary after being copied from a
permanent one, and that the copied temporary slot will be associated to
the session doing the copy:

    =# SELECT pg_copy_logical_replication_slot('physical_slot_1', 'logical_slot_2');
    ERROR:  0A000: cannot copy logical replication slot "physical_slot_1" as a physical replication slot
    LOCATION:  copy_replication_slot, slotfuncs.c:673
    =# SELECT * FROM pg_copy_physical_replication_slot('physical_slot_1', 'physical_slot_temp', true);
         slot_name      | lsn
    --------------------+------
     physical_slot_temp | null
    (1 row)
    =# SELECT slot_name, temporary, restart_lsn FROM pg_replication_slots;
         slot_name      | temporary | restart_lsn
    --------------------+-----------+-------------
     physical_slot_1    | f         | 0/15CF098
     physical_slot_2    | f         | 0/15CF098
     physical_slot_temp | t         | 0/15CF098
    (3 rows)

The copy of logical slots also has many usages.  As logical replication
makes use of a slot on the
[publication side](https://www.postgresql.org/docs/devel/sql-createpublication.html)
which is then consumed by a
[subscription](https://www.postgresql.org/docs/devel/sql-createsubscription.html),
this makes the debugging of such configurations easier, particularly if
there is a conflict of some kind on the target server.  The most interesting
property is that it is possible to change two properties of a slot when
copying it:

  * Change a slot from being permanent or temporary.
  * More importantly, change the output plugin of a slot.

In the context of logical replication, the output plugin being used is
pgoutput, and here is how to copy a logical slot with a new, different
plugin.  At creation the third argument controls if a slot is temporary
or not:

    =# SELECT * FROM pg_create_logical_replication_slot('logical_slot_1', 'pgoutput', false);
       slot_name    |    lsn
    ----------------+-----------
     logical_slot_1 | 0/15CF7C0
    (1 row)
    =# SELECT * FROM pg_copy_logical_replication_slot('logical_slot_1', 'logical_slot_2', false, 'test_decoding');
       slot_name    |    lsn
    ----------------+-----------
     logical_slot_2 | 0/15CF7C0
    (1 row)
    =# SELECT slot_name, restart_lsn, plugin FROM pg_replication_slots
         WHERE slot_type = 'logical';
       slot_name    | restart_lsn |    plugin
    ----------------+-------------+---------------
     logical_slot_1 | 0/15CF788   | pgoutput
     logical_slot_2 | 0/15CF788   | test_decoding
    (2 rows)

And then the secondary slot can be looked at with more understandable
data as it prints text records of logical changes happening.  This can
be consumed with the SQL functions like pg\_logical\_slot\_get\_changes as
well as a client like
[pg_recvlogical](https://www.postgresql.org/docs/devel/app-pgrecvlogical.html).
