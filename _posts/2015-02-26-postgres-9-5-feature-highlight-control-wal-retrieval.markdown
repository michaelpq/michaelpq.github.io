---
author: Michael Paquier
lastmod: 2015-02-26
date: 2015-02-26 07:11:15+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-control-wal-retrieval
title: 'Postgres 9.5 feature highlight - Control WAL retrieval with wal_retrieve_retry_interval'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.5
- wal
- replication

---

Up to Postgres 9.4, when a node in recovery checks for the availability of
WAL from a source, be it a WAL stream, WAL archive or local pg_xlog and that
it fails to obtain what it wanted, it has to wait for a mount of 5s, amount
of time hardcoded directly in xlog.c. 9.5 brings more flexibility with a
built-in parameter allowing to control this interval of time thanks to this
commit:

    commit: 5d2b45e3f78a85639f30431181c06d4c3221c5a1
    author: Fujii Masao <fujii@postgresql.org>
    date: Mon, 23 Feb 2015 20:55:17 +0900
    Add GUC to control the time to wait before retrieving WAL after failed attempt.

    Previously when the standby server failed to retrieve WAL files from any sources
    (i.e., streaming replication, local pg_xlog directory or WAL archive), it always
    waited for five seconds (hard-coded) before the next attempt. For example,
    this is problematic in warm-standby because restore_command can fail
    every five seconds even while new WAL file is expected to be unavailable for
    a long time and flood the log files with its error messages.

    This commit adds new parameter, wal_retrieve_retry_interval, to control that
    wait time.

    Alexey Vasiliev and Michael Paquier, reviewed by Andres Freund and me.

wal\_retrieve\_retry\_interval is a SIGHUP parameter (possibility to update
it by reloading parameters without restarting server) of postgresql.conf
that has the effect to control this check interval when a node is in recovery.
This parameter is useful when set to values shorter than its default of 5s
to increase for example the interval of time a warm-standby node tries to
get WAL from a source, or on the contrary a higher value can help to reduce
log noise and attempts to retrieve a missing WAL archive repetitively when
for example WAL archives are located on an external instance which is priced
based on the amount of connections attempted or similar (note as well that
a longer interval can be done with some timestamp control using a script that
is kicked by restore_command, still it is good to have a built-in option
to do it instead of some scripting magic).

Using this parameter is simple, for example with a warm-standby node set
as follows:

    $ grep -e wal_retrieve_retry_interval -e log_line_prefix postgresql.conf
    wal_retrieve_retry_interval = 100ms
    log_line_prefix = 'time %m:'
    $ cat recovery.conf
    # Track milliseconds easily for each command kicked
    restore_command = 'echo $(($(date +%%s%%N)/1000000)) && cp -i /path/to/wal/archive/%f %p'
    standby_mode = on
    recovery_target_timeline = 'latest'

The following successive attempts are done to try to get WAL:

    1424966099438
    cp: cannot stat '/home/ioltas/archive/5432/000000010000000000000004': No such file or directory
    1424966099539
    cp: cannot stat '/home/ioltas/archive/5432/000000010000000000000004': No such file or directory
    # 101 ms of difference

And then after switching to 20s:

    1424966322364
    cp: cannot stat '/home/ioltas/archive/5432/000000010000000000000005': No such file or directory
    1424966342387
    cp: cannot stat '/home/ioltas/archive/5432/000000010000000000000005': No such file or directory
    # 20023ms of difference

Something else to note is that the wait processing has been switched from
pg_usleep that may not stop on certain platforms after receiving a signal
to a latch, improving particularly a postmaster death detection.
