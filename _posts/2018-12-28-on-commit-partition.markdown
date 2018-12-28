---
author: Michael Paquier
lastmod: 2018-12-28
date: 2018-12-28 03:45:08+00:00
layout: post
type: post
slug: on-commit-partition
title: 'ON COMMIT actions with inheritance and partitions'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- bug
- partition
- inherit
- table

---

[The following bug fix](https://git.postgresql.org/pg/commitdiff/319a810)
has been committed to the PostgreSQL code tree, addressing an issue visibly
since ON COMMIT support for CREATE TABLE has been added back in commit
[ebb5318](https://git.postgresql.org/pg/commitdiff/ebb5318) from 2002:

    commit: 319a8101804f3b62512fdce1a3af1c839344b593
    author: Michael Paquier <michael@paquier.xyz>
    date: Fri, 9 Nov 2018 10:03:22 +0900
    Fix dependency handling of partitions and inheritance for ON COMMIT

    This commit fixes a set of issues with ON COMMIT actions when used on
    partitioned tables and tables with inheritance children:
    - Applying ON COMMIT DROP on a partitioned table with partitions or on a
    table with inheritance children caused a failure at commit time, with
    complains about the children being already dropped as all relations are
    dropped one at the same time.
    - Applying ON COMMIT DELETE on a partition relying on a partitioned
    table which uses ON COMMIT DROP would cause the partition truncation to
    fail as the parent is removed first.

    The solution to the first problem is to handle the removal of all the
    dependencies in one go instead of dropping relations one-by-one, based
    on a suggestion from Álvaro Herrera.  So instead all the relation OIDs
    to remove are gathered and then processed in one round of multiple
    deletions.

    The solution to the second problem is to reorder the actions, with
    truncation happening first and relation drop done after.  Even if it
    means that a partition could be first truncated, then immediately
    dropped if its partitioned table is dropped, this has the merit to keep
    the code simple as there is no need to do existence checks on the
    relations to drop.

    Contrary to a manual TRUNCATE on a partitioned table, ON COMMIT DELETE
    does not cascade to its partitions.  The ON COMMIT action defined on
    each partition gets the priority.

    Author: Michael Paquier
    Reviewed-by: Amit Langote, Álvaro Herrera, Robert Haas
    Discussion: https://postgr.es/m/68f17907-ec98-1192-f99f-8011400517f5@lab.ntt.co.jp
    Backpatch-through: 10

For beginners, ON COMMIT actions can be defined as part of
[CREATE TABLE](https://www.postgresql.org/docs/devel/sql-createtable.html) on
a temporary table to perform action during commits of transactions using it:

  * The default, PRESERVE ROWS, does nothing on the relation.
  * DELETE ROWS will perform a truncation of the relation.
  * DROP will remove the temporary relation at commit.

Immediate consequences of those definitions is that creating a temporary table
which uses DROP out of a transaction context immediately drops it:

    =# CREATE TEMP TABLE temp_drop (a int) ON COMMIT DROP;
    CREATE TABLE
    =# \d temp_drop
    Did not find any relation named "temp_drop".

Or inserting tuples out of a transaction into a relation which uses DELETE
ROWS lets the relation empty:

    =# CREATE TEMP TABLE temp_delete_rows (a int) ON COMMIT DELETE ROWS;
    CREATE TABLE
    =# INSERT INTO temp_delete_rows VALUES (1);
    INSERT 0 1
    =# TABLE temp_delete_rows;
     a
    ---
    (0 rows)

The bug fixed by the commit mentioned above involves the dependencies between
partitions and inheritance trees for relations.  First there are a couple of
restrictions to be aware of when using partitions or inheritance trees which
include temporary tables:

  * Temporary partitions can be added to a partitioned table only if the
  partitioned table it is attaching to is temporary.  This may be relaxed
  in future versions depending on the user interest.
  * For inheritance trees, temporary child relations can inherit from the
  parent if it is either temporary or non-temporary.  So if the child is not
  a temporary relation, its parent cannot be temporary.

Then some problems showed up when mixing ON COMMIT actions across multiple
layers of inheritance or partitions as the code has for a long time been
running the DROP actions on each relation individually and afterwards the
truncation of each relation, which led to interesting behaviors at transaction
commit time.  Here is
[an example](https://www.postgresql.org/message-id/20181102051804.GV1727@paquier.xyz):

    =# BEGIN;
    BEGIN
    =# CREATE TEMP TABLE temp_parent (a int) PARTITION BY LIST (a)
         ON COMMIT DROP;
    =# CREATE TEMP TABLE temp_child_2 PARTITION OF temp_parent
         FOR VALUES IN (2) ON COMMIT DELETE ROWS;
    CREATE TABLE
    =# INSERT INTO temp_parent VALUES (2);
    INSERT 0 1
    =# TABLE temp_parent;
     a
    ---
     2
    (1 row)
    =# COMMIT;
    ERROR: XX000: could not open relation with OID 16420
    LOCATION: relation_open, heapam.c:1138

So what happens here is that the parent is removed, causing its partitions
to go away, then the follow-up truncation on the child simply fails.  Fixing
this set of issues has required reordering a bit the code so as the relation
removals and truncations happen consistently:

  * The truncations happen first on all the relations where DELETE ROWS is
  defined.
  * Relation removal happens afterwards, with all the relations dropped in
  one shot using Postgres dependency machinery.

This means that child relations may get truncated uselessly if the parent
is dropped at the end, but that keeps the code logic simple.  Another thing
to be aware of is that this bug fix has only found its way down to Postgres
10, which has added as option PERFORM\_DELETION\_QUIETLY so as the cascading
removal of the children does not cause noise NOTICE messages.  As nobody
has complained about this bug for 15 years, and partitions begin (introduced
in v10) are just beginning to get used in applications that's a limitation
not worth worrying about.  Note also that ON COMMIT actions are not inherited
from the parent, so each action needs to be enforced and defined to each
member, with the default being to preserve rows.
