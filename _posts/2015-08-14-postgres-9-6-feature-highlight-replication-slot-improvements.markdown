---
author: Michael Paquier
OBlastmod: 2015-08-14
date: 2015-08-14 07:15:11+00:00
layout: post
type: post
slug: postgres-9-6-feature-highlight-replication-slot-improvements
title: 'Postgres 9.6 feature highlight: Replication slot improvements'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- highlight
- feature
- slot
- replication
- 9.6
- wal
- start

---

Today here are highlights about new features regarding replication slots
that have been lately committed and will be present as part of PostgreSQL
9.5:

    commit: 6fcd88511f8e69e38defb1272e0042ef4bab2feb
    author: Andres Freund <andres@anarazel.de>
    date: Tue, 11 Aug 2015 12:34:31 +0200
    Allow pg_create_physical_replication_slot() to reserve WAL.

    When creating a physical slot it's often useful to immediately reserve
    the current WAL position instead of only doing after the first feedback
    message arrives. That e.g. allows slots to guarantee that all the WAL
    for a base backup will be available afterwards.

    Logical slots already have to reserve WAL during creation, so generalize
    that logic into being usable for both physical and logical slots.

When 9.4 has introduced replication slots, both physical slots (for
replication) and logical slots (for logical decoding), one difference between
both slot types is that at the time of their creation, a logical slot retains
WAL all the time, and a physical slot did not. The commit above reduces the
difference gap by making possible to retain WAL when creating a physical
slot as well, with the addition of a boolean switch in
pg\_create\_physical\_replication\_slot which is false by default, meaning
that no WAL is kept until the slot is not used at least once. This is
particularly useful for example for base backups, that have been extended
a couple of days before this commit with an additional --slot option to
ensure that WAL is present on source while taking a backup. Here is how
this feature behaves:

    =# SELECT * FROM pg_create_physical_replication_slot('default_slot', false);
      slot_name   | xlog_position
    --------------+---------------
     default_slot | null
    (1 row)
    =# SELECT * FROM pg_create_physical_replication_slot('reserve_slot', true);
      slot_name   | xlog_position
    --------------+---------------
     reserve_slot | 0/1738850
    =# SELECT slot_name, restart_lsn from pg_replication_slots;
      slot_name   | restart_lsn
    --------------+-------------
     default_slot | null
     reserve_slot | 0/1738850
    (2 rows)

And the slot that has been marked to retain WAL has its position restart\_lsn
set at creation. (Note in any case that the replication protocol has not been
extended to support this option).

The second feature that has been committed regarding replication slots
is this one:

    commit: 3f811c2d6f51b13b71adff99e82894dd48cee055
    author: Andres Freund <andres@anarazel.de>
    date: Mon, 10 Aug 2015 13:28:18 +0200
    Add confirmed_flush column to pg_replication_slots.

    There's no reason not to expose both restart_lsn and confirmed_flush
    since they have rather distinct meanings. The former is the oldest WAL
    still required and valid for both physical and logical slots, whereas
    the latter is the location up to which a logical slot's consumer has
    confirmed receiving data. Most of the time a slot will require older
    WAL (i.e. restart_lsn) than the confirmed
    position (i.e. confirmed_flush_lsn).

As already explained in the commit message, this adds in the system view
pg\_replication\_slots the possibility to track up to which LSN position
a consumer of a slot has confirmed flushing the data received. And it is
available like that:

    =# SELECT * FROM pg_create_logical_replication_slot('logical_slot', 'test_decoding');
      slot_name   | xlog_position
    --------------+---------------
     logical_slot | 0/1738A90
    (1 row)
    =# SELECT slot_name, restart_lsn, confirmed_flush_lsn FROM pg_replication_slots;
      slot_name   | restart_lsn | confirmed_flush_lsn
    --------------+-------------+---------------------
     logical_slot | 0/1738A58   | 0/1738A90
    (1 row)

This is actually really helpful to get a view of how much a client
consuming logical changes has caught up in terms of flushing data,
and this is more consistent with what for example pg\_stat\_replication
reports when there are active WAL senders on a server instance.
