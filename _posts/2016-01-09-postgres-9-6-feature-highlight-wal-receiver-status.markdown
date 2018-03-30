---
author: Michael Paquier
lastmod: 2016-01-09
date: 2016-01-09 13:10:22+00:00
layout: post
type: post
slug: postgres-9-6-feature-highlight-wal-receiver-status
title: 'Postgres 9.6 feature highlight - WAL receiver status via SQL'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.6
- wal
- receiver
- monitoring

---

Following the [recent post](/postgresql-2/track-wal-receiver-state/) related
to the extension that gives a representation of a WAL receiver doing WAL
recovery via streaming, here is its equivalent in-core, for a new feature
that will be available in Postgres 9.6:

    commit: b1a9bad9e744857291c7d5516080527da8219854
    author: Alvaro Herrera <alvherre@alvh.no-ip.org>
    date: Thu, 7 Jan 2016 16:21:19 -0300
    pgstat: add WAL receiver status view & SRF

    This new view provides insight into the state of a running WAL receiver
    in a HOT standby node.
    The information returned includes the PID of the WAL receiver process,
    its status (stopped, starting, streaming, etc), start LSN and TLI, last
    received LSN and TLI, timestamp of last message send and receipt, latest
    end-of-WAL LSN and time, and the name of the slot (if any).

    Access to the detailed data is only granted to superusers; others only
    get the PID.

    Author: Michael Paquier
    Reviewer: Haribabu Kommi

So, what has been added here is a new system view called [pg\_stat\_wal\_receiver]
(http://www.postgresql.org/docs/devel/static/monitoring-stats.html#PG-STAT-WAL-RECEIVER-VIEW)
that offers to the user a set of information equivalent to the extension
presented in the previous post, except that this has the advantage to not
rely on any external things, making it available immediately in-box, and to
be precisely documented, for sure the best point. When connecting to a node
performing streaming on the receiver-side, here is the information present:

    =# \d pg_stat_wal_receiver
                View "pg_catalog.pg_stat_wal_receiver"
            Column         |           Type           | Modifiers
    -----------------------+--------------------------+-----------
     pid                   | integer                  |
     status                | text                     |
     receive_start_lsn     | pg_lsn                   |
     receive_start_tli     | integer                  |
     received_lsn          | pg_lsn                   |
     received_tli          | integer                  |
     last_msg_send_time    | timestamp with time zone |
     last_msg_receipt_time | timestamp with time zone |
     latest_end_lsn        | pg_lsn                   |
     latest_end_time       | timestamp with time zone |
     slot_name             | text                     |
    =# SELECT * FROM pg_stat_wal_receiver;
    -[ RECORD 1 ]---------+------------------------------
    pid                   | 12939
    status                | streaming
    receive_start_lsn     | 0/3000000
    receive_start_tli     | 1
    received_lsn          | 0/3000888
    received_tli          | 1
    last_msg_send_time    | 2016-01-09 21:19:03.812829+09
    last_msg_receipt_time | 2016-01-09 21:19:03.812864+09
    latest_end_lsn        | 0/3000888
    latest_end_time       | 2016-01-09 21:19:03.812829+09
    slot_name             | null

If this system view is queried on a node that does not have a WAL receiver,
no tuples are returned. In the case of a non-superuser, all fields are
hidden except the process PID. This is going to be useful for monitoring
purposes, and to ease lookups at the WAL receiver process, which was
up to 9.5 something that users had to look at through for example ps
with sometimes needs to directly parse its output.
