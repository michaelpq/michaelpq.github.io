---
author: Michael Paquier
lastmod: 2014-07-28
date: 2014-07-28 01:44:28+00:00
layout: post
type: post
slug: postgres-dynamic-tracing
title: 'Dynamic tracing with Postgres'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- trace
- track
- process
- probe
- systemtap
- linux
- dtrace
---
Postgres has in-core support for [Dynamic tracing]
(http://www.postgresql.org/docs/devel/static/dynamic-trace.html), which
is the possibility to use an external utility to track specific code path
calls and have an execution trace at disposition for further analysis.
Enabling this feature can be done when compiling code by specifying
--enable-dtrace at [configure]
(http://www.postgresql.org/docs/devel/static/install-procedure.html) step.
Note as well that on Linux systems you will need systemtap installed
(development package for compilation may be needed depending on your
platform) to be able to compile code with this support, and extra
kernel-level packages like kernel-devel to be able to take traces. In
order to check if your installation is able to do dynamic tracing, for
example simply run the following "Hello World" command.

    $ stap -e 'probe begin { printf("Hello World\n") exit() }'
    Hello World

Now, there are many things that can be done using the probes that are
defined within Postgres and the functions defined natively, the most
intuitive thing being to print on-the-fly information about things being
done on the Postgres server. Here is for example a script able to track
transaction start and commit, giving  at the same time some extra information
about the process doing the operation:

    probe process("/path/to/bin/postgres").mark("transaction__start")
    {
        printf ("Start PID: %d, CPU: %d\n", pid(), cpu())
    }

    probe process("/path/to/bin/postgres").mark("transaction__commit")
    {
        printf ("Commit PID: %d, CPU: %d\n", pid(), cpu())
    }

When using systemtap, the separator for mark points is not a single dash "-"
but a double underscore "\_\_". The argument values within a probe mark can be
accessed as wel in the stap script as $arg1, $arg2, etc. Now, running a simple
transaction like this one...

    =# BEGIN;
    BEGIN
    =# CREATE TABLE dtrace_tab (a int);
    CREATE TABLE
    =# select pg_backend_pid();
     pg_backend_pid
     ----------------
               14411
    (1 row)
    =# COMMIT;
    COMMIT

Results in the following output when running stap and the script.

    $ sudo stap tx_track.d
    Start PID: 14411, CPU: 0
    Commit PID: 14411, CPU: 0

It is as well possible to track function calls, here is an example tracking
the same information as the last script, but now by tracking calls of
StartTransaction and CommitTransaction. Such function is more interesting to
track specific code paths like planner or execution things though:

    probe process("/path/to/bin/postgres").function("StartTransaction")
    {
        printf ("Start PID: %d, CPU: %d\n", pid(), cpu())
    }

    probe process("/path/to/bin/postgres").function("CommitTransaction")
    {
        printf ("Commit PID: %d, CPU: %d\n", pid(), cpu())
    }

And a transaction similar to the previous one results in this output
(transaction run with the same session):

    $ sudo stap tx_func.d
    Start PID: 14411, CPU: 0
    Commit PID: 14411, CPU: 0

Using probes with a timer makes possible to print at a wanted interval of
time information about things that occurred on server. Here is an example
calculating the server TPS counting the transaction commits and printing
results every second:

    global commit_count

    probe process("/path/to/bin/postgres").mark("transaction__commit") {
        commit_count++
    }

    probe timer.s(1) {
        printf("tps: %d\n", commit_count)
        commit_count=0
    }

A simple run of pgbench like that (no tuning of any kind):

    $ pgbench -S -T 5 -c 24
    starting vacuum...end.
    transaction type: SELECT only
    scaling factor: 1
    query mode: simple
    number of clients: 24
    number of threads: 1
    duration: 5 s
    number of transactions actually processed: 14756
    latency average: 8.132 ms
    tps = 2941.653159 (including connections establishing)
    tps = 2975.574118 (excluding connections establishing)

Results in the following output:

    $ sudo stap tps_count.d
    tps: 2091
    tps: 2991
    tps: 3089
    tps: 2960
    tps: 3034
    tps: 624

Priting only information gathered once the stap process is stopped
can be done using probe end. Here is for example a script counting
the number of buffers flushed and read.

    probe process("/path/to/bin/postgres").mark("buffer__read__done")
    {
        buffer_read++
    }
    probe process("/path/to/bin/postgres").mark("buffer__flush__done")
    {
        buffer_flush++
    }
    probe end
    {
        printf("\nNumber of buffers read/flushed\n")
        printf("Read = %d\n", buffer_read)
        printf("Flushed = %d\n", buffer_flush)
    }

And now here is when running a short pgbench run followed by a checkpoint:

    $ pgbench -T 60 -c 24 | tail -n4
    starting vacuum...end.
    number of transactions actually processed: 24608
    latency average: 58.518 ms
    tps = 394.921180 (including connections establishing)
    tps = 395.289723 (excluding connections establishing)
    $ psql -c 'checkpoint'
    CHECKPOINT

The following results are obtained:

    $ sudo stap buffer_track.d
    ^C
    Number of buffers read/flushed
    Read = 927040
    Flushed = 2204

There are of course many possibilities with this facility, so be sure to
adapt it to your own needs and use it wisely. [perf]
(https://wiki.postgresql.org/wiki/Profiling_with_perf) offers as well
similar features for probe functions, and can work on existing binaries.
