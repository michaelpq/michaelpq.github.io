---
author: Michael Paquier
lastmod: 2018-04-11
date: 2018-04-11 06:01:32+00:00
layout: post
type: post
slug: postgres-11-covering indexes
title: 'Postgres 11 highlight - Covering Indexes'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 11
- indexes

---

INCLUDE clause for indexes (as known as covering indexes), is a new feature
of PostgreSQL 11 which has been committed recently:

    commit: 8224de4f42ccf98e08db07b43d52fed72f962ebb
    author: Teodor Sigaev <teodor@sigaev.ru>
    date: Sat, 7 Apr 2018 23:00:39 +0300
    Indexes with INCLUDE columns and their support in B-tree

    This patch introduces INCLUDE clause to index definition.  This clause
    specifies a list of columns which will be included as a non-key part in
    the index.  The INCLUDE columns exist solely to allow more queries to
    benefit from index-only scans.  Also, such columns don't need to have
    appropriate operator classes.  Expressions are not supported as INCLUDE
    columns since they cannot be used in index-only scans.

    Index access methods supporting INCLUDE are indicated by amcaninclude flag
    in IndexAmRoutine.  For now, only B-tree indexes support INCLUDE clause.

    In B-tree indexes INCLUDE columns are truncated from pivot index tuples
    (tuples located in non-leaf pages and high keys).  Therefore, B-tree indexes
    now might have variable number of attributes.  This patch also provides
    generic facility to support that: pivot tuples contain number of their
    attributes in t_tid.ip_posid.  Free 13th bit of t_info is used for indicating
    that.  This facility will simplify further support of index suffix truncation.
    The changes of above are backward-compatible, pg_upgrade doesn't need special
    handling of B-tree indexes for that.

    Bump catalog version

    Author: Anastasia Lubennikova with contribition by Alexander Korotkov and me
    Reviewed by: Peter Geoghegan, Tomas Vondra, Antonin Houska, Jeff Janes,
    David Rowley, Alexander Korotkov
    Discussion: https://www.postgresql.org/message-id/flat/56168952.4010101@postgrespro.ru

Touching close to 90 files for roughly 1500 of lines of code added, the
feature is large and introduces a couple of new concepts in the code.

This feature is really cool, as it allows one's application to make
use of index-only scans while leveraging index size and constraints
applying on a set of columns.  First, let's look at how one would do
to be able to get an index-only scan with a match on multiple columns
with a subset of them included in a constraint.  In order to do that,
it is necessary to create two indexes: one which covers all the columns
on which an index-only scan has to happen, and one which covers the
columns on which a constraint is applied.

    =# CREATE TABLE old_example (a int, b int, c int);
    CREATE TABLE
    =# INSERT INTO old_example
         SELECT 3 * val, 3 * val + 1, 3 * val + 2
         FROM generate_series(0, 1000000) as val;
    INSERT 0 1000001
    =# CREATE UNIQUE INDEX old_unique_idx ON old_example(a, b);
    CREATE INDEX
    =# VACUUM ANALYZE;
    VACUUM

With this set, is is possible to use an index-only scan if the
selectivity happens on the columns listed in the constraints (order
matters of course), and if the data retrieved matches the constraint.
Please note that I am cheating with the real format of EXPLAIN to
ease the read of this post, and the data is the same:

    =# EXPLAIN ANALYZE SELECT a, b FROM old_example WHERE a < 1000;
                          QUERY PLAN
    -----------------------------------------------------
     Index Only Scan using old_unique_idx on old_example
         (cost=0.42..10.17 rows=328 width=8)
         (actual time=0.069..0.236 rows=334 loops=1)
       Index Cond: (a < 1000)
       Heap Fetches: 0
     Planning Time: 0.286 ms
     Execution Time: 0.337 ms
    (5 rows)

Once an extra column is fetched, then performance drops (not here!),
when a column out of the constraint is included no more index-only
scans, and an index scan is used to retrieve the data from heap:

    =# EXPLAIN ANALYZE SELECT a, b, c FROM old_example WHERE a < 1000;
                        QUERY PLAN
    -------------------------------------------------
     Index Scan using old_unique_idx on old_example
         (cost=0.42..571.23 rows=328 width=12)
         (actual time=0.063..0.366 rows=334 loops=1)
       Index Cond: (a < 1000)
     Planning Time: 0.310 ms
     Execution Time: 0.466 ms
    (4 rows)

If you want to get an index-only scan for all columns here without a
constraint, then it is necessary to create a secondary index like this
one:

    =# CREATE INDEX old_idx ON old_example (a, b, c);
    CREATE INDEX
    =# VACUUM ANALYZE;
    VACUUM

And then the query saves lookups to the heap with an index-only scan:

    =# EXPLAIN ANALYZE SELECT a, b, c FROM old_example WHERE a < 1000;
                         QUERY PLAN
    -------------------------------------------------
     Index Only Scan using old_idx on old_example
         (cost=0.42..14.92 rows=371 width=12)
         (actual time=0.086..0.291 rows=334 loops=1)
       Index Cond: (a < 1000)
       Heap Fetches: 0
     Planning Time: 2.108 ms
     Execution Time: 0.396 ms
    (5 rows)

However this has its downsides as it is necessary to maintain two
indexes, which cost in size on disk, as well as in maintenance for
vacuums which need to clean up and delete more entries in pages,
dealing with twice the amount of work.

This is where the feature introduced by this commit is useful.  By
using a list of columns in the INCLUDE query which has been added
to [CREATE INDEX](https://www.postgresql.org/docs/devel/static/sql-createindex.html),
then one can split the columns where a constraint is in effect, but
still add columns which can be part of an index-only scan, and which
are *not* part of the constraint.  Hence using the new method, you
can get the same result as previously with the following set of
queries:

    =# CREATE TABLE new_example (a int, b int, c int);
    CREATE TABLE
    =# INSERT INTO new_example
         SELECT 3 * val, 3 * val + 1, 3 * val + 2
         FROM generate_series(0, 1000000) as val;
    INSERT 0 1000001
    =# CREATE UNIQUE INDEX new_unique_idx ON new_example(a, b)
         INCLUDE (c);
    CREATE INDEX
    =# VACUUM ANALYZE;
    VACUUM
    =#  EXPLAIN ANALYZE SELECT a, b, c FROM new_example WHERE a < 10000;
                           QUERY PLAN
    -----------------------------------------------------
     Index Only Scan using new_unique_idx on new_example
         (cost=0.42..116.06 rows=3408 width=12)
         (actual time=0.085..2.348 rows=3334 loops=1)
       Index Cond: (a < 10000)
       Heap Fetches: 0
     Planning Time: 1.851 ms
     Execution Time: 2.840 ms
    (5 rows)

Hence this time it is possible to cover the same set of cases
with only one index, meaning less maintenance tasks for PostgreSQL
and less on-disk data.

Note that this feature comes with a set of restrictions.  First the
feature is only supported for btree indexes.  Then, and this is logic,
there cannot be any overlap between columns in the main column list
and those from the include list:

    =# CREATE UNIQUE INDEX new_unique_idx ON new_example(a, b)
         INCLUDE (a);
    ERROR:  42P17: included columns must not intersect with key columns
    LOCATION:  DefineIndex, indexcmds.c:373

However note that a column used with an expression in the main list
works:

    =# CREATE UNIQUE INDEX new_unique_idx_2
       ON new_example(round(a), b) INCLUDE (a);
    CREATE INDEX

Also note that expressions cannot be used in an include list because
they cannot be used in an index-only scan:

    =# CREATE UNIQUE INDEX new_unique_idx_2 ON new_example(a, b) INCLUDE (round(c));
    ERROR:  0A000: expressions are not supported in included columns
    LOCATION:  ComputeIndexAttrs, indexcmds.c:1446

That's really something which will improve the life of many developers,
so Postgres 11 is heading to becoming a nice tool to look closely for.
