---
author: Michael Paquier
comments: true
lastmod: 2014-03-12
date: 2014-03-12 15:35:08+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-replication-phydical-slots
title: 'Postgres 9.4 feature highlight: Physical slots for replication'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.4
- open source
- database
- development
- replication
- slot
- wal
- pg_xlog
- wal
- file
- replay
- track
- keep
- conserve
- monitor
- physical
- replication
---
Replication slots is a new feature of PostgreSQL 9.4 that has been introduced
by this commit:

    commit 858ec11858a914d4c380971985709b6d6b7dd6fc
    Author: Robert Haas <rhaas@postgresql.org>
    Date:   Fri Jan 31 22:45:17 2014 -0500

    Introduce replication slots.

    Replication slots are a crash-safe data structure which can be created
    on either a master or a standby to prevent premature removal of
    write-ahead log segments needed by a standby, as well as (with
    hot_standby_feedback=on) pruning of tuples whose removal would cause
    replication conflicts.  Slots have some advantages over existing
    techniques, as explained in the documentation.

    In a few places, we refer to the type of replication slots introduced
    by this patch as "physical" slots, because forthcoming patches for
    logical decoding will also have slots, but with somewhat different
    properties.

    Andres Freund and Robert Haas

This feature has been designed to be part of a set for the support of [logical
replication](http://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=5a991ef8692ed0d170b44958a81a6bd70e90585c),
but it can be used independently to force a master server to keep WAL files
that are still needed by a standby node (note that for more theorical details,
you can refer as well to [this blog post]
(http://blog.2ndquadrant.com/postgresql-9-4-slots/) by Craig Ringer, here the
focus is made more on how to use it). There are two types of replication slots:
logical and physical. Logical slots have the property to be able to connect to
a particular database, while physical slots are more general. I'll come back
in more details to logical decoding in some future posts as well as there
is much to tell about that, for now let's talk only about physical replication
slots. One property that both share is the conservation of WAL files though.

In the case of a standby node using streaming replication, the server does not
actually wait for the slave to catch up if it disconnects and simply deletes
the WAL files that are not needed. This has the advantage to facilitate
management of the disk space used by WAL files: use checkpoint\_segments
as well in this case. The amount of WAL to keep on master side can as well
be tuned with wal\_keep\_segments, but this is more a hack than anything
else...

However, when using replication slots with standby nodes, a master node
retains the necessary WAL files in pg\_xlog until the standby has received
them. This has somewhat the advantage of facilitating a cluster configuration,
at the cost of monitoring the space used by WAL files in pg\_xlog as now
the disk space that those filesuse is not strictly controlled by
wal\_keep\_segments or checkpoint\_segments but by elements (perhaps) external
to the server where the master node is running. So be extremely careful when
using this feature: a standby node disconnected for a long time might have
as consequence to completely fill in the partition used for WAL files.
So this is something to perhaps avoid if pg\_xlog is put on a different
partition with limited disk space, space surely chosen to satisfy some
cluster configuration or design needs.

Configuring a standby to use physical replication slots is simple. First
create a physical replication slot on the master node of your cluster:

    =# SELECT pg_is_in_recovery();
     pg_is_in_recovery 
    -------------------
     f
    (1 row)
    =# SELECT * FROM pg_create_physical_replication_slot('slot_1');
     slotname | xlog_position 
    ----------+---------------
     slot_1   | null
    (1 row)

A necessary condition to be able to create replication slots is to set
max_replication_slots to a value higher than 0 or the following error
happens:

    =# SELECT * FROM pg_create_physical_replication_slot('slot_1');
    ERROR:  55000: replication slots can only be used if max_replication_slots > 0
    LOCATION:  CheckSlotRequirements, slot.c:760

And then set primary\_slotname in [recovery.conf]
(http://www.postgresql.org/docs/devel/static/standby-settings.html).
This setting has no effect if primary\_conninfo is not set. recovery.conf
will look like that:

    primary_slotname = 'slot_1'
    primary_conninfo = 'port=5432 application_name=node_5433'
    standby_mode = on

If the standby node is stopped for a long time and that you wish
to monitor its WAL replay progress with pg\_stat\_replication on the
master node, you might want as well to not use restore\_command
(approach not recommended though!).

The status of each replication slot can be monitored via a dedicated
system view called pg\_replication\_slots.

    =# SELECT * FROM pg_replication_slots ;
    -[ RECORD 1 ]+----------
    slot_name    | slot_1
    plugin       | null
    slot_type    | physical
    datoid       | null
    database     | null
    active       | t
    xmin         | null
    catalog_xmin | null
    restart_lsn  | 0/4000278

Dropping a replication slot can be done with pg\_drop\_replication\_slot,
note however that it is not possible to drop an active slot:

    =# select pg_drop_replication_slot('slot_1');
    ERROR:  55006: replication slot "slot_1" is already active
    LOCATION:  ReplicationSlotAcquire, slot.c:339

A last thing, do not finish like that:

    $ psql -c 'SELECT slot_name, active, restart_lsn FROM pg_replication_slots'
     slot_name | active | restart_lsn 
    -----------+--------+-------------
     slot_1    | f      | 0/4000278
    (1 row)
    $ du -h $PGDATA/pg_xlog | tail -n 1 | cut -f 1
    17.8G
