---
author: Michael Paquier
lastmod: 2019-04-09
date: 2019-04-09 10:14:37+00:00
layout: post
type: post
slug: postgres-12-pg-checksums
title: 'Postgres 12 highlight - pg_checksums'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 12
- checksum

---

[pg\_checksums](https://www.postgresql.org/docs/devel/app-pgchecksums.html)
is a renaming of the tool called pg\_verify\_checksums which has been
introduced in Postgres 11.  Version 12 is introducing new options and
possibilities which explain the renaming, as the tool has become much
more multi-purpose.

First, it is now possible to enable and disable checksums for an offline
cluster:

    commit: ed308d78379008b2cebca30a986f97f992ee6122
    author: Michael Paquier <michael@paquier.xyz>
    date: Sat, 23 Mar 2019 08:12:55 +0900
    Add options to enable and disable checksums in pg_checksums

    An offline cluster can now work with more modes in pg_checksums:
    - --enable enables checksums in a cluster, updating all blocks with a
    correct checksum, and updating the control file at the end.
    - --disable disables checksums in a cluster, updating only the control
    file.
    - --check is an extra option able to verify checksums for a cluster, and
    the default used if no mode is specified.

    When running --enable or --disable, the data folder gets fsync'd for
    durability, and then it is followed by a control file update and flush
    to keep the operation consistent should the tool be interrupted, killed
    or the host unplugged.  If no mode is specified in the options, then
    --check is used for compatibility with older versions of pg_checksums
    (named pg_verify_checksums in v11 where it was introduced).

    Author: Michael Banck, Michael Paquier
    Reviewed-by: Fabien Coelho, Magnus Hagander, Sergei Kornilov
    Discussion: https://postgr.es/m/20181221201616.GD4974@nighthawk.caipicrew.dd-dns.de


Here is how it works.  The tool is able to do three modes now in
total:

  * --check, the default if nothing is specified and what
  pg\_verify\_checksums was already able to do.  This mode scans all the
  relation file blocks, reporting any mismatch.
  * --enable, which enables data checksums.  This rewrites all the
  relation file blocks, and finishes the operation by updating the
  control file.  Note that this can be take time depending on the size
  of the instance, and that the tool has no parallel mode.
  * --disables which disables data checksums by only updating the
  control file.

Hence, taking a cluster which has data checksums disabled, here is how
to enable them.  First the instance to switch needs to be cleanly shut
down:

    $ pg_controldata -D /my/data/folder/ | grep state
    Database cluster state:               shut down

And then enabling data checksums is a matter of running this command,
where the change gets reflected to the control file:

    $ pg_checksums --enable -D /my/data/folder/
    Checksum operation completed
    Files scanned:  1144
    Blocks scanned: 3487
    pg_checksums: syncing data directory
    pg_checksums: updating control file
    Checksums enabled in cluster
    $ pg_controldata -D /my/data/folder/ | grep checksum
    Data page checksum version:           1

Repeating the same operation results in a failure (disabling data checksums
where they are already disabled share the same fate):

    $ pg_checksums --enable -D /my/data/folder/
    pg_checksums: error: data checksums are already enabled in cluster

Then disabling checksums can be done like that:

    $ pg_checksums --disable -D /my/data/folder/
    pg_checksums: syncing data directory
    pg_checksums: updating control file
    Checksums disabled in cluster
    $ pg_checksums --disable -D /my/data/folder/
    pg_checksums: error: data checksums are already disabled in cluster
    $ pg_controldata | grep checksum
    Data page checksum version:           0

Finally, note that the tool is able to handle failures or interruptions
in-between gracefully.  For example, if the host in the process enabling
data checksums is plugged off, then the data folder will remain in a state
where they are disabled as the update of the control file happens last.
Hence, the operation can be retried from scratch.

pg\_verify\_checksums is already a rather powerful tool when it comes
to backup validation, but enabling checksums after an upgrade was still
a barrier.  Using Postgres 10, it is possible to use logical replication
with a new instance initialized to have data checksums enabled when using
initdb, still this takes time and resources as the initial data copy could
take long.  Note that if you have a cluster which relies on backup tools
doing physical copy of relation blocks,
[pg\_rewind](https://www.postgresql.org/docs/devel/app-pgrewind.html) being
such an tool, it is possible to finish with a cluster which has checksums
enabled still some pages could be broken if these pages come from a cluster
having checksums disabled.  Hence if switching checksums in a set of Postgres
nodes, you should be careful to enable checksums consistently on all nodes
at the same time.

Now, as data checksums are only compiled when a session flushes a page to
disk or at shared buffer eviction, and because WAL do not need to compile
checksums even if a full-page write is taken, enabling checksums with
minimum downtime becomes much easier by relying on physical replication
(WAL streaming).  For example, assuming that no physical copy of relation
blocks are done across multiple nodes, one could do the following with a
set of two nodes, a primary and a standby:

  * Both primary and standby have data checksums disabled, and the goal
  is to enable data checksums.
  * First, stop cleanly the standby, and enable checksums on it with
  --enable.
  * Start the standby, and make it catch up with the primary.
  * Stop cleanly the primary.
  * Promote the standby and do a failover to it.
  * Enable checksums on the previous primary.
  * Plug it back to the promoted standby, both instances have now
  checksums enabled.

On top of that, an option to output the progress of any operation run has
been added:

    commit: 280e5f14056bf34a0f52320f659fb93acfda0876
    author: Michael Paquier <michael@paquier.xyz>
    date: Tue, 2 Apr 2019 10:58:07 +0900
    Add progress reporting to pg_checksums

    This adds a new option to pg_checksums called -P/--progress, showing
    every second some information about the computation state of an
    operation for --check and --enable (--disable only updates the control
    file and is quick).  This requires a pre-scan of the data folder so as
    the total size of checksummable items can be calculated, and then it
    gets compared to the amount processed.

    Similarly to what is done for pg_rewind and pg_basebackup, the
    information printed in the progress report consists of the current
    amount of data computed and the total amount of data to compute.  This
    could be extended later on.

    Author: Michael Banck, Bernd Helmle
    Reviewed-by: Fabien Coelho, Michael Paquier
    Discussion: https://postgr.es/m/1535719851.1286.17.camel@credativ.de


Note that this is valid only for --check and --enable. Reports are every
second, as follows (this is a fresh instance):

    $ pg_checksums --enable --progress
    27/27 MB (100%) computed

This requires an extra scan of the data folder so as it is possible to
know the total size of all elements having checksums beforehand, costing
some extra resources, but it can be useful for reporting when the
operation takes a long time on a large cluster.
