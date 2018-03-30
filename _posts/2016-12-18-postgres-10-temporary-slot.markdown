---
author: Michael Paquier
lastmod: 2016-12-18
date: 2016-12-18 12:25:24+00:00
layout: post
type: post
slug: postgres-10-temporary-slot
title: 'Postgres 10 highlight - Temporary replication slots'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 10
- replication
- slot

---

Postgres 10 has support for an additional feature related to
[replication slots](https://www.postgresql.org/docs/devel/static/warm-standby.html#streaming-replication-slots),
a facility holding a way to retain WAL data in pg_xlog depending on
the data consumed by clients connected to it. The feature spoken about
here has been implemented by the following commit:

    Add support for temporary replication slots

    This allows creating temporary replication slots that are removed
    automatically at the end of the session or on error.

    From: Petr Jelinek <petr.jelinek@2ndquadrant.com>

As the commit log already mentions, replication slots have the possibility
to be made temporary. When created, they are associated with the connection
that created them, and once the connection session finishes, the slots are
automatically dropped. Note as well that the slots have no consistent data
on disk, so on crash those are of course dropped as well (it's not like
Postgres crashes a lot anyway, per its reputation for stability).

One direct application of this feature is the case where WAL segments are
needed by this client and that they absolutely need this data to be consistent
with what has been done and that the slot is a one-shot need. In existing
Postgres versions, any application can create a slot, be it via SQL or
the replication protocol, though any failure results in a cleanup logic
that needs to be done or WAL would be retained infinitely if the cleanup
work does not happen. At this end that would crash the backend once the
partition holding pg\_xlog gets full.

Once this commit has been done,
[a patch has been sent](https://www.postgresql.org/message-id/CABUevEzviwzspA3XUkXpK-H6UL-9t3=C=7Bw-qJMgCYjLDed9A@mail.gmail.com)
for pg\_basebackup to make use of temporary slots. This is a perfect match
for the use of temporary replication slots as many users are already using
the stream mode of pg\_basebackup to fetch the WAL segments with a secundary
replication connection to be sure that segments are included to make a full
consistent backup that can be used as-is when restoring an instance.

The main risk of using pg\_basebackup without replication slots is to
not be able to take a consistent backup as WAL segments may have been
already recycled. This can be mitigated using the backend-side parameter
wal\_keep\_segments but this is not exact science. This risk is higher
with the fetch mode, still it exists as well with the stream mode.
Since Postgres 9.6, replication slots can be used but those need to
be permanent so there is a risk to cause the bloat of pg\_xlog in case
of repetitive failures of backup creation. Any backup application logic
should do cleanup of existing replication slots to avoid this problem...
So considering all that temporary replication slots for pg\_basebackup
are really useful. In other potential applications, pg\_receivexlog could
benefit from it as well.

Temporary replication slots can be created in two ways. First using the
replication protocol.

    $ psql -d "replication=1"
    =# CREATE_REPLICATION_SLOT temp_slot TEMPORARY PHYSICAL;
     slot_name | consistent_point | snapshot_name | output_plugin
    -----------+------------------+---------------+---------------
     temp_slot | 0/0              | null          | null
    (1 row)


The second way is by using directly the existing SQL functions
pg\_create\_physical\_replication\_slot() and
pg\_create\_logical\_replication\_slot() that have been extended with a
third argument defaulting to false to define if the slot created is
temporary or not:

    =# SELECT * FROM pg_create_physical_replication_slot('temp_slot_2', false, true);
      slot_name  | xlog_position
    -------------+---------------
     temp_slot_2 | null
    (1 row)

Note that as long at the session is active other sessions can check if the
slot is present. The system view pg\_replication\_slots has as well been
extended with a column called "temporary" to track the persistency of the
slot.

    =# SELECT slot_name, temporary FROM pg_replication_slots;
      slot_name  | temporary
    -------------+-----------
     temp_slot   | t
     temp_slot_2 | t
    (1 row)

And one those sessions are over, so are the created slot. It is of course
possible to reserve immediately WAL on a temporary slot.
