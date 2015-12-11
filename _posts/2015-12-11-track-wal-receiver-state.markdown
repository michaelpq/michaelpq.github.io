---
author: Michael Paquier
OBlastmod: 2015-12-11
date: 2015-12-11 05:35:22+00:00
layout: post
type: post
slug: track-wal-receiver-state
title: 'Tracking WAL receiver status during replication via SQL'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- commit
- streaming
- replication
- tracking
- WAL
- receiver
- process
- shared
- memory
- SQL
- function
- view

---

In the series of extensions making the life of operators and DBAs easier,
and after the facility to easy the tracking of Postgres backend processes
[waiting for synchronous replication](/postgresql-2/track-commit-synchronous/),
here is a new feature that has been added to the existing module
[pg\_rep\_state](https://github.com/michaelpq/pg_plugins/tree/master/pg_rep_state)
aimed at representing at SQL level what shared memory holds for a WAL
receiver (a WAL receiver being what is used on a backend receiving WAL
in replication from a root node via streaming).

Postgres is already able to report the process output of a WAL receiver for
example using ps like that, and this can give an indication about how this
process is working:

    $ ps x | grep "wal receiver"
    58030   ??  Ss     0:00.48 postgres: wal receiver process   streaming 0/302B710

If an application needs to know what is the status of replication on a
given node, looking at this output can give an indication about what is
going on, however parsing that adds at application level some extra
machinery.

So, here is an extension allowing to represent this WAL receiver status
directly at SQL level. This is quite simple: this translates the data
of WalRcvData (walreceiver.h) present in shared memory directly as a
single tuple. The extension can be installed as follows after compilation:

    =# CREATE EXTENSION pg_rep_state;
    CREATE EXTENSION
    =# \dx+ pg_rep_state
    Objects in extension "pg_rep_state"
            Object Description
    ----------------------------------
     function pg_syncrep_state()
     function pg_wal_receiver_state()
     view pg_syncrep_state
     view pg_wal_receiver_state
    (4 rows)

On a master node or a node not performing streaming replication via
streaming during recovery, the WAL receiver is represented as a NULL
tuple:

    =# SELECT pid, status FROM pg_wal_receiver_state;
     pid  | status
    ------+--------
     null | null
    (1 row)

On a streaming standby though, things get more verbose:

    =# SELECT pid, status, received_up_to_lsn FROM pg_wal_receiver_state;
      pid  |  status   | received_up_to_lsn
    -------+-----------+--------------------
     58030 | streaming | 0/3060AD8
    (1 row)

And that's exactly what ps reports as well regarding this process:

    $ ps x | grep "wal receiver"
    58030   ??  Ss     0:00.89 postgres: wal receiver process   streaming 0/3060AD8

Hopefully you will find that useful.
