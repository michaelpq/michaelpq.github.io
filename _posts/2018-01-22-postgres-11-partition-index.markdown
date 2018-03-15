---
author: Michael Paquier
lastmod: 2018-01-22
date: 2018-01-22 05:32:53+00:00
layout: post
type: post
slug: postgres-11-partition-index
title: 'Postgres 11 highlight - Indexes and Partitions'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- 11
- indexes
- partition
- inheritance
- list
- child
- automatic

---

Postgres 10 has introduced a lot of basic infrastructure for table
partitioning with the presence of mainly a new syntax, and a lot of work
happens in this area lately with many new features added in version 11
which is currently in development. This post is about the following
commit:

    commit: 8b08f7d4820fd7a8ef6152a9dd8c6e3cb01e5f99
    author: Alvaro Herrera <alvherre@alvh.no-ip.org>
    date: Fri, 19 Jan 2018 11:49:22 -0300
    Local partitioned indexes

    When CREATE INDEX is run on a partitioned table, create catalog entries
    for an index on the partitioned table (which is just a placeholder since
    the table proper has no data of its own), and recurse to create actual
    indexes on the existing partitions; create them in future partitions
    also.

    As a convenience gadget, if the new index definition matches some
    existing index in partitions, these are picked up and used instead of
    creating new ones.  Whichever way these indexes come about, they become
    attached to the index on the parent table and are dropped alongside it,
    and cannot be dropped on isolation unless they are detached first.

    To support pg_dump'ing these indexes, add commands
        CREATE INDEX ON ONLY <table>
    (which creates the index on the parent partitioned table, without
    recursing) and
        ALTER INDEX ATTACH PARTITION
    (which is used after the indexes have been created individually on each
    partition, to attach them to the parent index).  These reconstruct prior
    database state exactly.

    Reviewed-by: (in alphabetical order) Peter Eisentraut, Robert Haas, Amit
        Langote, Jesper Pedersen, Simon Riggs, David Rowley
    Discussion: https://postgr.es/m/20171113170646.gzweigyrgg6pwsg4@alvherre.pgsql

This feature is much useful for the handling of indexes for partitioned
tables by giving the possibility to create indexes in an automatic way:

  * Any index created on a partition table will be created as well on
  each existing child tables.
  * Any future partition added will gain the same index as well.

For example, taking this layer of partitioned tables:

            p
           / \
          /   \
         p10  p20
             /   \
            /     \
           p21    p22

The parent table, as well as its children only have one column, and
are defined as follows (that is not representative of any sane application
layer, still enough to demonstrate the feature):

    =# CREATE TABLE p (a int) PARTITION BY RANGE (a);
    CREATE TABLE
    =# CREATE TABLE p10 PARTITION OF p FOR VALUES FROM (0) TO (10)
	   PARTITION BY RANGE(a);
    CREATE TABLE
    =# CREATE TABLE p20 PARTITION OF p FOR VALUES FROM (10) TO (20)
	   PARTITION BY RANGE(a);
    CREATE TABLE
    =# CREATE TABLE p21 PARTITION OF p20 FOR VALUES FROM (10) TO (11);
    CREATE TABLE
    =# CREATE TABLE p22 PARTITION OF p20 FOR VALUES FROM (11) TO (12);
    CREATE TABLE

With the feature above, the creation of an index gets executed to all
partitions. So, for example creating an index on 'p' results in the same
being created down to all partitions, even down to p21 which is two levels
down:

    =# CREATE INDEX pi ON p(a);
    CREATE INDEX
    =# \d p21
                    Table "public.p21"
     Column |  Type   | Collation | Nullable | Default
    --------+---------+-----------+----------+---------
     a      | integer |           |          |
    Partition of: p20 FOR VALUES FROM (10) TO (11)
    Indexes:
        "p21_a_idx" btree (a)

Note that the index creation only gets down, so by creating an index on
say 'p20', the definition gets down to 'p21' and 'p22', but not the
parent 'p':

    =# CREATE INDEX p20i ON p20(a);
    CREATE INDEX
    =# \d p21
                    Table "public.p21"
     Column |  Type   | Collation | Nullable | Default
    --------+---------+-----------+----------+---------
     a      | integer |           |          |
    Partition of: p20 FOR VALUES FROM (10) TO (11)
    Indexes:
        "p21_a_idx" btree (a)
        "p21_a_idx1" btree (a)
    =# \d p
                     Table "public.p"
     Column |  Type   | Collation | Nullable | Default
    --------+---------+-----------+----------+---------
     a      | integer |           |          |
    Partition key: RANGE (a)
    Indexes:
        "pi" btree (a)
	Number of partitions: 2 (Use \d+ to list them.)

Any new partition created also gets those new indexes created by default:

    =# CREATE TABLE p23 PARTITION OF p20 FOR VALUES FROM (12) TO (13);
    CREATE TABLE
    =# \d p23
                    Table "public.p23"
     Column |  Type   | Collation | Nullable | Default
    --------+---------+-----------+----------+---------
     a      | integer |           |          |
    Partition of: p20 FOR VALUES FROM (12) TO (13)
    Indexes:
        "p23_a_idx" btree (a)
        "p23_a_idx1" btree (a)

As mentioned by the commit message, using the new extension of CREATE
INDEX called ON ONLY stops any recursion lookup:

    =# CREATE INDEX pi2 ON ONLY p(a);
    CREATE INDEX
    -- No new index on the child
	=# \d p10
                    Table "public.p10"
     Column |  Type   | Collation | Nullable | Default
    --------+---------+-----------+----------+---------
     a      | integer |           |          |
    Partition of: p FOR VALUES FROM (0) TO (10)
    Partition key: RANGE (a)
    Indexes:
        "p10_a_idx" btree (a)
    Number of partitions: 0

For anybody relying on the new partition features, this is going to be
a huge win in portability, as there is no need to wrap all those index
creations into for example a plpgsql call which executes a series of DDL
commands to do such operations.
