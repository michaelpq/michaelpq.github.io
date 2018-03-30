---
author: Michael Paquier
lastmod: 2016-10-23
date: 2016-10-23 13:48:34+00:00
layout: post
type: post
slug: postgres-10-wait-event-latches
title: 'Postgres 10 highlight - Wait events for latches'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 10
- wait
- event
- monitoring

---

Postgres 9.6 has added a really cool infrastructure called wait events.
This allows a developer to define in the code being run a wait point
that gets reported to the system statistics via it PGPROC entry. In
short, a custom wait point in the code gets reported and is then visible
in system catalogs. In this case this is pg\_stat\_activity via the columns
wait\_event\_type and wait\_event. 9.6 infrastructure shows up information
for backend processes holding lightweight locks, heavyweight locks, and
buffer pins. While getting a look at this infrastructure, I got surprised
by the fact that nothing was reported for latches, more or less code paths
calling WaitLatch() to wait for a timeout, a postmaster death, a socket event
or just for the latch to be set. As 9.6 was close to shipping when I bumped
into the limitation, nothing much could be done for it. So this got delayed
to Postgres 10, and has been committed recently with the following change:

    commit: 6f3bd98ebfc008cbd676da777bb0b2376c4c4bfa
    author: Robert Haas <rhaas@postgresql.org>
    date: Tue, 4 Oct 2016 11:01:42 -0400
    Extend framework from commit 53be0b1ad to report latch waits.

    WaitLatch, WaitLatchOrSocket, and WaitEventSetWait now taken an
    additional wait_event_info parameter; legal values are defined in
    pgstat.h.  This makes it possible to uniquely identify every point in
    the core code where we are waiting for a latch; extensions can pass
    WAIT_EXTENSION.

    Because latches were the major wait primitive not previously covered
    by this patch, it is now possible to see information in
    pg_stat_activity on a large number of important wait events not
    previously addressed, such as ClientRead, ClientWrite, and SyncRep.

    Unfortunately, many of the wait events added by this patch will fail
    to appear in pg_stat_activity because they're only used in background
    processes which don't currently appear in pg_stat_activity.  We should
    fix this either by creating a separate view for such information, or
    else by deciding to include them in pg_stat_activity after all.

    Michael Paquier and Robert Haas, reviewed by Alexander Korotkov and
    Thomas Munro

The primary use-case that came to mind while looking at this new feature
is the possibility to track which backends are being stuck because of
a commit confirmation coming from a standby with synchronous streaming
replication. There are ways to discover that using extensions, two of them
are for example my own extension
[pg\_rep\_state](https://github.com/michaelpq/pg_plugins/tree/master/pg_rep_state)
or Fujii Masao's
[pg\_cheat\_funcs](https://github.com/MasaoFujii/pg_cheat_funcs/blob/master/pg_cheat_funcs.c)
though both require a lock on SyncRepLock to scan the PGPROC entries,
something that could impact performance for a large number of backends to
scan, of course depending on the frequency of the scan. Most users will not
care about that though. The new wait event infrastructure has the advantage
to *not* require the acquisition of such a lock, users just need to look
at the wait event SyncRep for the same result. Let's have a look at that
then with a single Postgres instance, whose commits will get stuck because
synchronous\_standby\_names points to a standby that does not exist:

    =# ALTER SYSTEM SET synchronous_standby_names = 'not_exists';
    ALTER SYSTEM
    =# SELECT pg_reload_conf();
     pg_reload_conf
    ----------------
     t
    (1 row)
    =# CREATE TABLE mytab (); -- Remains stuck

And from another session:

    =# SELECT query, wait_event_type, wait_event
       FROM pg_stat_activity WHERE wait_event is NOT NULL;
              query         | wait_event_type | wait_event
    ------------------------+-----------------+------------
     CREATE TABLE mytab (); | IPC             | SyncRep
    (1 row)

So the result here is really cool, wait\_event being set to what is
expected. Note that the wait event types of those new wait points have
been classified by category, per an idea of Robert Haas who committed the
patch to clarify a bit more what each wait point is about. For example,
"IPC" refers to a process waiting for some activity from another process,
"Activity" means that the process is basically idle, etc.
[The documentation](https://www.postgresql.org/docs/devel/static/monitoring-stats.html)
on the matter has all the information that matters.

A limitation of the feature is that it is not possible to look at the wait
points of auxiliary system processes, like the startup process at recovery,
the archiver, autovacuum launcher, etc. It would be possible to get that
working by patching a bit more the upstream code. Background workers can
by the way show up in pg\_stat\_activity so it is possible to include in them
custom wait points that are then monitored.

An important use-case of this feature is performance analysis. The set of
wait points available makes it far easier to locate where are the contention
points of a given application by monitoring pg\_stat\_activity at a fixed
frequency. For example, if accumulated events involve a lot of ClientRead
events, it means that backends are usually waiting a lot for information
from a client. 9.6 allows some analysis based on a lookup of the locks
taken but being able to look at the additional bottlenecks like the
client-server communication completes the set and allows far deeper analysis
of benchmarks using the in-core structure of Postgres. But let's take a
short example with a pgbench database initialized at scale 10, with a run
of 24 clients:

    $ pgbench -i -s 10
    [...]
    set primary keys...
    done.
    $ pgbench -c 24 -T 65
    [...]

And in parallel to that let's store the events periodically in a custom
table, using psql's \watch command to store the events that can be found:

    =# CREATE TABLE wait_events (wait_event_type text, wait_event text);
    CREATE TABLE
    =# INSERT INTO wait_events
       SELECT wait_event_type, wait_event
         FROM pg_stat_activity
         WHERE pid != pg_backend_pid();
    INSERT 0 24
    =# \watch 5
    [... 12 samples are taken ...]

Once the run is done, here is a simple way to analyze this collected data:

    =# SELECT count(*) AS cnt, wait_event, wait_event_type
       FROM wait_events
       GROUP BY (wait_event, wait_event_type) ORDER BY cnt;
     cnt |  wait_event   | wait_event_type
    -----+---------------+-----------------
      24 | tuple         | Lock
      39 | transactionid | Lock
      66 | null          | null
     159 | ClientRead    | Client
    (5 rows)

In which case the conclusion is plain: a lot of backends have just kept
waiting for pgbench to get something to do so they ran in an idle state
most of the time. Take this example lightly, this is not a workload that
one would see in the real world, still this new tooling opens a lot of
new exciting prospectives when benchmarking Postgres, be it for new
feature benchmark or just a product. And this is cross-platform, so
Windows is no issue.
