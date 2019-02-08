---
author: Michael Paquier
lastmod: 2019-02-08
date: 2019-02-08 03:50:47+00:00
layout: post
type: post
slug: postgres-12-partition-funcs
title: 'Postgres 12 highlight - Functions for partitions'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 12
- function
- partition

---

Partitions in Postgres are a recent concept, being introduced as of version
10 and improved a lot over the last years.  It is complicated, and doable,
to gather information about them with specific queries working on the system
catalogs, still these may not be straight-forward.  For example, getting a
full partition tree leads to the
[use of WITH RECURSIVE](/postgresql-2/partition-information/) when working
on partitions with multiple layers.

Postgres 12 is coming with improvements in this regard with two commits.
The first one introduces a new system function to get easily information
about a full partition tree:

    commit: d5eec4eefde70414c9929b32c411cb4f0900a2a9
    author: Michael Paquier <michael@paquier.xyz>
    date: Tue, 30 Oct 2018 10:25:06 +0900
    Add pg_partition_tree to display information about partitions

    This new function is useful to display a full tree of partitions with a
    partitioned table given in output, and avoids the need of any complex
    WITH RECURSIVE query when looking at partition trees which are
    deep multiple levels.

    It returns a set of records, one for each partition, containing the
    partition's name, its immediate parent's name, a boolean value telling
    if the relation is a leaf in the tree and an integer telling its level
    in the partition tree with given table considered as root, beginning at
    zero for the root, and incrementing by one each time the scan goes one
    level down.

    Author: Amit Langote
    Reviewed-by: Jesper Pedersen, Michael Paquier, Robert Haas
    Discussion: https://postgr.es/m/8d00e51a-9a51-ad02-d53e-ba6bf50b2e52@lab.ntt.co.jp

The second function is able to find the top-most parent of a partition
tree:

    commit: 3677a0b26bb2f3f72d16dc7fa6f34c305badacce
    author: Michael Paquier <michael@paquier.xyz>
    date: Fri, 8 Feb 2019 08:56:14 +0900
    Add pg_partition_root to display top-most parent of a partition tree

    This is useful when looking at partition trees with multiple layers, and
    combined with pg_partition_tree, it provides the possibility to show up
    an entire tree by just knowing one member at any level.

    Author: Michael Paquier
    Reviewed-by: Álvaro Herrera, Amit Langote
    Discussion: https://postgr.es/m/20181207014015.GP2407@paquier.xyz

First let's take a set of partitions, working on two layers with an
index defined for all of them:

    CREATE TABLE parent_tab (id int) PARTITION BY RANGE (id);
    CREATE INDEX parent_index ON parent_tab (id);
    CREATE TABLE child_0_10 PARTITION OF parent_tab
         FOR VALUES FROM (0) TO (10);
    CREATE TABLE child_10_20 PARTITION OF parent_tab
         FOR VALUES FROM (10) TO (20);
    CREATE TABLE child_20_30 PARTITION OF parent_tab
         FOR VALUES FROM (20) TO (30);
    INSERT INTO parent_tab VALUES (generate_series(0,29));
    CREATE TABLE child_30_40 PARTITION OF parent_tab
         FOR VALUES FROM (30) TO (40)
         PARTITION BY RANGE(id);
    CREATE TABLE child_30_35 PARTITION OF child_30_40
         FOR VALUES FROM (30) TO (35);
    CREATE TABLE child_35_40 PARTITION OF child_30_40
         FOR VALUES FROM (35) TO (40);
    INSERT INTO parent_tab VALUES (generate_series(30,39));

This set of partitioned tables with their partitions is really simple: one
parent with immediate children working on a range of values.  Then one
of the children, child\_30\_40 has itself partitions, defined using a
subset of its own range.  CREATE INDEX gets applied to all the partitions,
meaning that all these relations have a btree index on the column "id".

First, pg\_partition\_tree() will display a full tree of it, taking
in input a relation used as base point for the parent of the tree,
so using parent\_tab as input gives a complete tree:

    =# SELECT * FROM pg_partition_tree('parent_tab');
        relid    | parentrelid | isleaf | level
    -------------+-------------+--------+-------
     parent_tab  | null        | f      |     0
     child_0_10  | parent_tab  | t      |     1
     child_10_20 | parent_tab  | t      |     1
     child_20_30 | parent_tab  | t      |     1
     child_30_40 | parent_tab  | f      |     1
     child_30_35 | child_30_40 | t      |     2
     child_35_40 | child_30_40 | t      |     2
    (7 rows)

And using one of the children gives the element itself if the relation
is a leaf partition, or can give a sub-tree:

    =# SELECT * FROM pg_partition_tree('child_0_10');
       relid    | parentrelid | isleaf | level
    ------------+-------------+--------+-------
     child_0_10 | parent_tab  | t      |     0
    (1 row)
    =# SELECT * FROM pg_partition_tree('child_30_40');
        relid    | parentrelid | isleaf | level
    -------------+-------------+--------+-------
     child_30_40 | parent_tab  | f      |     0
     child_30_35 | child_30_40 | t      |     1
     child_35_40 | child_30_40 | t      |     1
    (3 rows)

Indexes part of partition trees are not at rest, and are handled
consistently as the relations they depend on:

    =# SELECT * FROM pg_partition_tree('parent_index');
           relid        |    parentrelid     | isleaf | level
    --------------------+--------------------+--------+-------
     parent_index       | null               | f      |     0
     child_0_10_id_idx  | parent_index       | t      |     1
     child_10_20_id_idx | parent_index       | t      |     1
     child_20_30_id_idx | parent_index       | t      |     1
     child_30_40_id_idx | parent_index       | f      |     1
     child_30_35_id_idx | child_30_40_id_idx | t      |     2
     child_35_40_id_idx | child_30_40_id_idx | t      |     2
    (7 rows)

The following fields show up:

  * relid is the OID, take it as relation name, for a given element
  in the tree.  This uses regclass as output to ease its use.
  * parentrelid refers to the immediate parent of the element.
  * isleaf will be true if the element does not have any partitions of
  its own.  In short it has physical storage.
  * level is a counter referring to the layer of the tree, beginning at
  0 for the top-most parent, then incremented by 1 each time it moves
  to the next layer.

When it comes to work with hundreds of partitions, this is first faster
than something going through all the catalog entries, like the specific
query using WITH RECURSIVE mentioned above (which could also be bundled
into an SQL function to provide the same results as the new in-core
functions introduced in this post).  A second advantage is that it makes
aggregate operations much easier and readable.  Getting the total
physical size covered by a given partition tree can be summarized by
that:

    =# SELECT pg_size_pretty(sum(pg_relation_size(relid)))
         AS total_partition_size
       FROM pg_partition_tree('parent_tab');
     total_partition_size
    ----------------------
     40 kB
    (1 row)

This works the same way for indexes, and switching to
pg\_total\_relation\_size() would also give the total physical space
used for a given partition tree with all the full set of indexes
included.

The second function, pg\_partition\_root() becomes handy when it comes
to work with complicated partition trees.  Depending on the application
policy where partitions are used, relation names can have structured
name policies, still from one version to another, and depending on the
addition of new features or logic layers, those policies can easily break,
leading to a mess first, and a hard time when it comes to figure out what
is actually the shape of the schema and the shape of a partition tree.
This function takes in input a relation name, and will return the top-most
parent of a partition tree:

    =# SELECT pg_partition_root('child_35_40');
     pg_partition_root
    -------------------
     parent_tab
    (1 row)

If the input is the top-most parent or a single relation, then the result
is itself:

    =# SELECT pg_partition_root('parent_tab');
     pg_partition_root
    -------------------
     parent_tab
    (1 row)
    =# CREATE TABLE single_tab ();
    CREATE TABLE
    =# SELECT pg_partition_root('single_tab');
     pg_partition_root
    -------------------
     single_tab
    (1 row)

Finally, with both combined, it is possible to get information about a
complete partition tree by just knowing one of its members:

    =# SELECT * FROM pg_partition_tree(pg_partition_root('child_35_40'));
        relid    | parentrelid | isleaf | level
    -------------+-------------+--------+-------
     parent_tab  | null        | f      |     0
     child_0_10  | parent_tab  | t      |     1
     child_10_20 | parent_tab  | t      |     1
     child_20_30 | parent_tab  | t      |     1
     child_30_40 | parent_tab  | f      |     1
     child_30_35 | child_30_40 | t      |     2
     child_35_40 | child_30_40 | t      |     2
    (7 rows)

A last thing to note is that those functions return NULL if the input
refers to a relation kind which cannot be part of a partition tree, like
a view or a materialized view, and not an error.  This makes easier the
creation of SQL queries doing for example scans of pg\_class as there is
no need to create more WHERE filters based on the relation kind.
