---
author: Michael Paquier
lastmod: 2021-05-30
date: 2021-05-30 06:57:01+00:00
layout: post
type: post
slug: postgres-14-reindex-tbspace
title: 'Postgres 14 highlight - REINDEX TABLESPACE'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 14
- index
- indexes
- reindex

---

The following feature has been committed into PostgreSQL 14, as of this
[commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=c5b28604):

    commit: c5b286047cd698021e57a527215b48865fd4ad4e
    author: Michael Paquier <michael@paquier.xyz>
    date: Thu, 4 Feb 2021 14:34:20 +0900
    Add TABLESPACE option to REINDEX

    This patch adds the possibility to move indexes to a new tablespace
    while rebuilding them.  Both the concurrent and the non-concurrent cases
    are supported, and the following set of restrictions apply:
    - When using TABLESPACE with a REINDEX command that targets a
    partitioned table or index, all the indexes of the leaf partitions are
    moved to the new tablespace.  The tablespace references of the non-leaf,
    partitioned tables in pg_class.reltablespace are not changed. This
    requires an extra ALTER TABLE SET TABLESPACE.
    - Any index on a toast table rebuilt as part of a parent table is kept
    in its original tablespace.
    - The operation is forbidden on system catalogs, including trying to
    directly move a toast relation with REINDEX.  This results in an error
    if doing REINDEX on a single object.  REINDEX SCHEMA, DATABASE and
    SYSTEM skip system relations when TABLESPACE is used.

    Author: Alexey Kondratov, Michael Paquier, Justin Pryzby
    Reviewed-by: Álvaro Herrera, Michael Paquier
    Discussion: https://postgr.es/m/8a8f5f73-00d3-55f8-7583-1375ca8f6a91@postgrespro.ru

The commit message is explicit enough: this adds a new clause to
[REINDEX](https://www.postgresql.org/docs/devel/sql-reindex.html) called
TABLESPACE.  The logic behind it is deadly simply, and offers the possibility
to move indexes into a new tablespace while rebuilding them.  Originally, this
was proposed for [CLUSTER](https://www.postgresql.org/docs/devel/sql-cluster.html)
as well as [VACUUM FULL](https://www.postgresql.org/docs/devel/sql-vacuum.html),
but REINDEX is the only query whose implementation has been completed for
this release.  The advantage for users is to avoid a potential two-step
process when willing to move a certain set of relations to a new disk
partition, in the even of an origin partition getting full for example.  When
it comes to REINDEX, a huge advantage of this operation is that a relation
can be moved while using CONCURRENTLY, hence an index can be rebuilt *and*
moved to a new tablespace, while allowing concurrent read and writes
during the reindex as this operation uses a SHARE UPDATE EXCLUSIVE lock
on the index and its parent table.

Before getting this feature done, some ground work has been done as REINDEX
accepts in 13 and older versions a limited set of options within its
parenthesized grammar, and did not allow extended boolean expressions
like VACUUM.  For the sake of TABLESPACE, the parser had to be modified
so as options are handled as a list of DefElems, with the utility execution
taking care of the option handling and value assignment.  Some choices have
been made to get an implementation close to VACUUM, where one cannot rely
on transaction-level memory context to store the options, because REINDEX
could run across multiple transactions (CONCURRENTLY or system/database
queries).

One take here is the support for tablespace moves while running REINDEX on
a partitioned table.  For simplicity's sake, we have made the choice to only
work on the partitions with physical storage and to not modify anything for
the partitioned tables.  Imagine the following example:

    =# CREATE TABLE parent_tab (id int) PARTITION BY RANGE (id);
    CREATE TABLE
    =# CREATE INDEX parent_index ON parent_tab (id);
    CREATE INDEX
    =# CREATE TABLE child_0_10 PARTITION OF parent_tab
         FOR VALUES FROM (0) TO (10);
    CREATE TABLE
    =# CREATE TABLE child_10_20 PARTITION OF parent_tab
         FOR VALUES FROM (10) TO (20);
    CREATE TABLE
    =# SELECT * FROM pg_partition_tree('parent_tab');
        relid    | parentrelid | isleaf | level
    -------------+-------------+--------+-------
     parent_tab  | null        | f      |     0
     child_0_10  | parent_tab  | t      |     1
     child_10_20 | parent_tab  | t      |     1
    (3 rows)
    =# SELECT * FROM pg_partition_tree('parent_index');
           relid        | parentrelid  | isleaf | level
    --------------------+--------------+--------+-------
     parent_index       | null         | f      |     0
     child_0_10_id_idx  | parent_index | t      |     1
     child_10_20_id_idx | parent_index | t      |     1
    (3 rows)

This is a simple partitioning tree, with one partitioned table called
'parent\_tab' and two partitions.  Each table has one index to build a
second, consistent partitioning tree.  Here is now what happens when
using REINDEX (TABLESPACE) with the partitioned table:

    =# \db extra_tbspace
                  List of tablespaces
         Name      |  Owner   |       Location
    ---------------+----------+---------------------
     extra_tbspace | postgres | /path/to/tablespace
     (1 row)
    =# REINDEX (TABLESPACE extra_tbspace) TABLE parent_tab;
     REINDEX
    =# SELECT c.relname, t.spcname
         FROM pg_partition_tree('parent_index') p
         JOIN pg_class c ON (c.oid = p.relid)
         JOIN pg_tablespace t ON (c.reltablespace = t.oid);
          relname       |    spcname
    --------------------+---------------
     child_0_10_id_idx  | extra_tbspace
     child_10_20_id_idx | extra_tbspace
    (2 rows)
	=# \d parent_index
    Partitioned index "public.parent_index"
     Column |  Type   | Key? | Definition
    --------+---------+------+------------
     id     | integer | yes  | id
    btree, for table "public.parent_tab"
    Number of partitions: 2 (Use \d+ to list them.)

The index of the partitioned table is *not* moved, but all the indexes of
the partitions are moved to the new tablespace.  A list of all the
partitions to work on is built in the first transaction running REINDEX,
and then each partition has all its indexes processed in one of more
transaction (CONCURRENTLY uses multiple transactions, of course).  However,
as only the relations with physical storage are processed, no tablespace
references are changed in the partitioned tables.  Updating
pg\_class.reltablespace for the full partition tree is more complex than
it looks as the existing operation supported by
[ALTER TABLE](https://www.postgresql.org/docs/devel/sql-altertable.html)
uses an exclusive lock but REINDEX may use a lower lock as an effect of
CONCURRENTLY.  So the choice has been made to keep the operation as
non-blocking, and it considers only the existing partitions when running
the operation.  Note that this has as effect that any new partition will
use the tablespace of the parent table if an ALTER TABLE ONLY has not
been used to change its tablespace after REINDEX, so be careful here.
Support for partitioned tables in REINDEX is new as of Postgres 14 as
well, so there are a lot of new features in this area and new shiny tools.

Also, something worth noting is that
[reindexdb](https://postgr.es/m/8a8f5f73-00d3-55f8-7583-1375ca8f6a91@postgrespro.ru)
has gained an extra option called --tablespace, to offer a wrapper for the
same clause in REINDEX.  This has been done in a
[separate commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=57e6db706e81fd2609fa385677e6ae72471822fe).
