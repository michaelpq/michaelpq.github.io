---
author: Michael Paquier
lastmod: 2014-10-16
date: 2014-10-16 06:20:37+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-physical-slot-pg-receivexlog
title: 'Postgres 9.5 feature highlight - Replication slot control with pg_receivexlog'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.5
- replication
- slot
- pg_receivexlog

---

Introduced in PostgreSQL 9.4, [pg\_recvlogical]
(http://www.postgresql.org/docs/devel/static/app-pgrecvlogical.html) has the
ability to control the creation of logical replication slots from which
logical changes can be streamed. Note that in the case this is a mandatory
condition when using [logical decoding]
(http://www.postgresql.org/docs/devel/static/logicaldecoding.html).
[pg\_receivexlog]
(http://www.postgresql.org/docs/devel/static/app-pgreceivexlog.html)
does not have in 9.4 any control on the physical replication slots it may
stream from (to ensure that the WAL segment files this utility is looking
for are still retained on the server side). This feature has been added
for 9.5 with the following commit:

    commit: d9f38c7a555dd5a6b81100c6d1e4aa68342d8771
    author: Andres Freund <andres@anarazel.de>
    date: Mon, 6 Oct 2014 12:51:37 +0200
    Add support for managing physical replication slots to pg_receivexlog.

    pg_receivexlog already has the capability to use a replication slot to
    reserve WAL on the upstream node. But the used slot currently has to
    be created via SQL.

    To allow using slots directly, without involving SQL, add
    --create-slot and --drop-slot actions, analogous to the logical slot
    manipulation support in pg_recvlogical.

    Author: Michael Paquier

This simply introduces two new options allowing to create or drop a physical
replication slot, respectively --create-slot and --drop-slot. The main
difference with pg\_recvlogical is that those additional actions are optional
(not --start option introduced as well for backward-compatibility). Be
careful of a couple of things when using this feature though. First, when a
slot is created, stream of the segment files begins immediately.

    $ pg_receivexlog --create-slot --slot physical_slot -v -D ~/xlog_data/
    pg_receivexlog: creating replication slot "physical_slot"
    pg_receivexlog: starting log streaming at 0/1000000 (timeline 1)

The slot created can then be found in the system view pg\_replication\_slots.

    =# select slot_name, plugin, restart_lsn from pg_replication_slots ;
       slot_name   | plugin | restart_lsn
    ---------------+--------+-------------
     physical_slot | null   | 0/1000000
	(1 row)

Then, when dropping a slot, as process can stream nothing it exits
immediately, and slot is of course not more:

    $ pg_receivexlog --drop-slot --slot physical_slot -v
    pg_receivexlog: dropping replication slot "physical_slot"
    $ psql -c 'SELECT slot_name FROM pg_replication_slots'
     slot_name
    -----------
    (0 rows)

Deletion and creation of the replication slot is made uses the same replication
connection as the one for stream and uses the commands CREATE\_REPLICATION\_SLOT
and DROP\_REPLICATION\_SLOT from the [replication protocol]
(http://www.postgresql.org/docs/devel/static/protocol-replication.html),
resulting in a light-weight implementation. So do not hesitate to refer to this
code when implementing your own client applications,
src/bin/pg_basebackup/streamutil.c being particularly helpful.
