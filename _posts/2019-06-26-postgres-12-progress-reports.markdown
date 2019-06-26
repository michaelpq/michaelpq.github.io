---
author: Michael Paquier
lastmod: 2019-06-26
date: 2019-06-26 06:17:11+00:00
layout: post
type: post
slug: postgres-12-progress-reports
title: 'Postgres 12 highlight - More progress reporting'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 12
- cluster
- reindex
- index

---

Since Postgres 11, it is possible to monitor progress activity of
running manual VACUUM and even autovacuum using a dedicated system
catalog called
[pg\_stat\_progress\_vacuum](https://www.postgresql.org/docs/devel/progress-reporting.html#VACUUM-PROGRESS-REPORTING).
This is vital for operators when doing some long-running operations,
because it is possible to not blindly wait for an operation to
finish.  When doing performance workload analysis, this is also
proving to be helpful in evaluating VACUUM job progressing for
tuning system-level parameters or even relation-level once depending
on the load pattern.

Postgres 12 has added more monitoring in this area thanks for a set of
commits.  Here is [the one](https://git.postgresql.org/pg/commitdiff/6f97457e0ddd8b421ca5e483439ef0318e6fc89a)
for CLUSTER and VACUUM FULL:

    commit: 6f97457e0ddd8b421ca5e483439ef0318e6fc89a
    author: Robert Haas <rhaas@postgresql.org>
    date: Mon, 25 Mar 2019 10:59:04 -0400
    Add progress reporting for CLUSTER and VACUUM FULL.

    This uses the same progress reporting infrastructure added in commit
    c16dc1aca5e01e6acaadfcf38f5fc964a381dc62 and extends it to these
    additional cases.  We lack the ability to track the internal progress
    of sorts and index builds so the information reported is
    coarse-grained for some parts of the operation, but it still seems
    like a significant improvement over having nothing at all.

    Tatsuro Yamada, reviewed by Thomas Munro, Masahiko Sawada, Michael
    Paquier, Jeff Janes, Alvaro Herrera, Rafia Sabih, and by me.  A fair
    amount of polishing also by me.

    Discussion: http://postgr.es/m/59A77072.3090401@lab.ntt.co.jp

And here is [the second one](https://git.postgresql.org/pg/commitdiff/ab0dfc961b6a821f23d9c40c723d11380ce195a6)
for CREATE INDEX and REINDEX:

    commit: ab0dfc961b6a821f23d9c40c723d11380ce195a6
    author: Alvaro Herrera <alvherre@alvh.no-ip.org>
    date: Tue, 2 Apr 2019 15:18:08 -0300
    Report progress of CREATE INDEX operations

    This uses the progress reporting infrastructure added by c16dc1aca5e0,
    adding support for CREATE INDEX and CREATE INDEX CONCURRENTLY.

    There are two pieces to this: one is index-AM-agnostic, and the other is
    AM-specific.  The latter is fairly elaborate for btrees, including
    reportage for parallel index builds and the separate phases that btree
    index creation uses; other index AMs, which are much simpler in their
    building procedures, have simplistic reporting only, but that seems
    sufficient, at least for non-concurrent builds.

    The index-AM-agnostic part is fairly complete, providing insight into
    the CONCURRENTLY wait phases as well as block-based progress during the
    index validation table scan.  (The index validation index scan requires
    patching each AM, which has not been included here.)

    Reviewers: Rahila Syed, Pavan Deolasee, Tatsuro Yamada
    Discussion: https://postgr.es/m/20181220220022.mg63bhk26zdpvmcj@alvherre.pgsql

So there is now support for progress reports with:

  * REINDEX and CREATE INDEX, using a new system catalog called
  [pg\_stat\_progress\_create\_index](https://www.postgresql.org/docs/devel/progress-reporting.html#CREATE-INDEX-PROGRESS-REPORTING)
  * CLUSTER and VACUUM FULL as both use the same code paths for
  the relation rewrites, using a new system catalog called
  [pg_stat_progress_cluster](https://www.postgresql.org/docs/devel/progress-reporting.html#CLUSTER-PROGRESS-REPORTING).

First, let's go through the new progress features for indexes.  One thing
to know is that this allows to track also the CONCURRENTLY flavors of CREATE
INDEX and REINDEX.  A concurrent reindex is roughly the combination of an
index created concurrently with an extra swap phase to switch some
dependencies between the former index and the new one.  For example, as
REINDEX CONCURRENTLY has in its processing to wait for all past transactions
to finish before marking a concurrently-created index as valid to be used.
This can create easily deadlock problems, which exist actually since CREATE
INDEX CONCURRENTLY exists.  For example, take the following table with one
index which gets locked:

    =# CREATE TABLE reindex_tab (id int PRIMARY KEY);
    CREATE TABLE
    =# INSERT INTO reindex_tab VALUES (generate_series(1, 10000));
    INSERT 0 10000
    =# BEGIN;
    BEGIN
    =# LOCK reindex_tab IN SHARE UPDATE EXCLUSIVE LOCK;
    LOCK TABLE;

Then trying to do the following query across two sessions results in a
deadlock, which will be solved depending on deadlock\_timeout:

    =# REINDEX INDEX CONCURRENTLY reindex_tab_pkey;
    [ ... waits for completion ... ]

At this stage, once the first session commits above and releases its lock,
it is possible to see the second session waiting for the transaction of
the third session to finish at a specific phase of the REINDEX:

    =# SELECT phase, command, index_relid::regclass
         FROM pg_stat_progress_create_index;
               phase           |       command        |   index_relid
    ---------------------------+----------------------+------------------
     waiting for old snapshots | REINDEX CONCURRENTLY | reindex_tab_pkey
    (1 row)

So this comes handy for monitoring the concurrency of the operation.  Note
that current\_locker\_pid includes the PID of the session being waited for.

This is also useful for a long-running process of course.  When facing an
index corruption, say on a catalog table where concurrent reindex is not
supported, it can be very stressing to wait for the operation to finish,
and REINDEX takes an exclusive lock on the parent table worked on.  In this
case, knowing about the total number of blocks and/or tuples still waiting
to be processed is very nice.  For example, reusing the previous relation
with more tuples, such reports are available (note that not all the fields
are used for each phase, and that the documentation mentions what gets used
with each phase properly ordered):

    =# SELECT index_relid::regclass, phase, blocks_done, blocks_total
         FROM pg_stat_progress_create_index;
       index_relid    |             phase              | blocks_done | blocks_total
    ------------------+--------------------------------+-------------+--------------
     reindex_tab_pkey | building index: scanning table |       27719 |        44248
    (1 row)
    =# SELECT index_relid::regclass, phase, tuples_done, tuples_total
         FROM pg_stat_progress_create_index;
       index_relid    |                 phase                  | tuples_done | tuples_total
    ------------------+----------------------------------------+-------------+--------------
     reindex_tab_pkey | building index: loading tuples in tree |     6913009 |     10000000
    (1 row)

Note as well that each phase is dependent on the index access method used,
which is btree in this example.

And then comes progress reporting for VACUUM FULL and CLUSTER.  Being able
to estimate the amount of time an operation is taking will help in reducing
the stress created by the fact of taking an exclusive lock on the relation
taken.  Each phase is documented in the docs, but the metric which is the
most helpful in this case is to look at the number of blocks scanned and
the number of blocks in total, so as it is possible to guess the work
remaining.

    =# SELECT command, relid::regclass, phase, heap_blks_scanned, heap_blks_total
         FROM pg_stat_progress_cluster ;
       command   |    relid    |       phase       | heap_blks_scanned | heap_blks_total
    -------------+-------------+-------------------+-------------------+-----------------
     VACUUM FULL | reindex_tab | seq scanning heap |             10482 |           44248
    (1 row)

Coupled with a regular snapshot of data taken, this can be used to  gather
statistics to estimate the amount of remaining time but more can be done.
The set of features included in Postgres core focus on their main goal
which is to gather raw and meaningful data, and the simple metrics about
the number of total elements (tuples, blocks) to work on and the number of
items processed are enough to track.
