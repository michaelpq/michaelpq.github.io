---
author: Michael Paquier
date: 2012-08-03 12:23:22+00:00
layout: page
type: page
slug: performance-tuning
title: PostgreSQL - Performance tuning
tags:
- postgres
- postgresql
- database
- open source
- performance
- tuning
- analyze
- statistics
- vacuum
- bloat
- index
- trick
---
Here are a couple of tips to boost the performance of a PostgreSQL database server.
  1. What to avoid
  2. Some general tricks
  3. Ugly SQL queries
  4. Indexing
  5. Vacuum
  6. Analyze

### 1. What to avoid

  * Do not run anything besides PostgreSQL on the host
  * If PostgreSQL is in a VM, remember all of the other VMs on the same
host
  * Disable the Linux OOM killer
  * Sessions in the database
  * Constantly-updated accumulator records
  * Task queues in the database
  * Using the database as a filesystem
  * Frequently-locked singleton records
  * Very long-running transactions
  * Using INSERT instead of COPY for a huge load of data
  * Mixing transactional and data warehouse queries on the same database

### 2. Some general tricks

If one model has a constantly updated section and a rarely updated section
(like a user record with a name and a last-seen-on-site field), split those
2 into 2 tables. This allows to the lock taken at tuple level and
reinforces the read on the second field. The tuple of the field read a lot
might be locked a lot die to the other field being continuously updated so
you can really improve performance here.

### 3. Ugly SQL queries

  * Gigantic IN clauses
  * Unanchored text queries like ‘%this%’; use the built-in full text
search instead
  * Small, high-volume queries processed by the application (Hello
"SELECT * FROM table")

### 4. Indexing

A good index has a high selectivity on commonly-performed queries or
is required to enforce a constraint. A bad index is everything else:
non-selective, rarely used, expensive to maintain. Only the first
column of a multi-column index can be used separately.

So...

  * Do not create index randomly.
  * Use pg\_stat\_user\_tables to find the sequential scans.
  * Use pg\_stat\_user\_indexes to see the index usage.

### 5. Vacuum

If autovacuum is slowing down the system, increase
autovacuum\_vacuum\_cost\_limit. If load is periodic, do manual VACUUM
instead at low times. Do not forget that you must VACUUM regularly.

### 6. Analyze

Analyze collects statistics on the data to help the planner choose a
good plan. This is done automatically as a part of autovacuum. You
should always do it manually after substantial database changes
(loads, etc.), and also do it as part of any VACUUM process done
manually.

### 7. I/O scheduler

The Linux kernel comes up with a set of scheduler that can be used to
alleviate the I/O behavior on disks and partitions.

  * noop, fine with SSDs, but can kill local disks on no-reordering
of writes. Has more effects for sequential I/O writes like WAL flush
by having pg_xlog on a different partition for example.
  * deadline, great for Postgres but interactive workloads are impacted
by it.
  * cfq, a good balance for everything, and it is the default on Linux.

It is usually better to stick with the default scheduler except when
trying to solve a specific issue, also everything else than cfq would
perform badly on non-enterprise class storages (SAN).

### 8. stats_temp_directory on a ramdisk

stats\_temp\_directory is a directory where temporary statistics are
stored, and they do not need to persist. pg\_stat\_tmp is the default.
Its size is usually a couple of hundred kilobytes. Here is how to set
a ramdisk for that.

Create the ramdisk partition.

    mkdir -p $TEMP_STAT_FOLDER
    chmod 777 $TEMP_STAT_FOLDER
    chmod +t $TEMP_STAT_FOLDER

Add new partition to /etc/fstab with a new dedicated entry:

    tmpfs $TEMP_STAT_FOLDER tmpfs size=2G,uid=$USER,gid=$GROUP 0 0

In postgresql.conf, add that, and then reload it:

    stats_temp_directory = '$TEMP_STAT_FOLDER'
