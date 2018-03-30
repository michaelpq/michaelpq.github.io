---
author: Michael Paquier
lastmod: 2014-11-12
date: 2014-11-12 08:35:47+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-brin-indexes
title: 'Postgres 9.5 feature highlight - BRIN indexes'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.5
- brin
- index

---

A new index type, called BRIN or Block Range INdex is showing up in
PostgreSQL 9.5, introduced by this commit:

    commit: 7516f5259411c02ae89e49084452dc342aadb2ae
    author: Alvaro Herrera <alvherre@alvh.no-ip.org>
    date: Fri, 7 Nov 2014 16:38:14 -0300
    BRIN: Block Range Indexes

    BRIN is a new index access method intended to accelerate scans of very
    large tables, without the maintenance overhead of btrees or other
    traditional indexes.  They work by maintaining "summary" data about
    block ranges.  Bitmap index scans work by reading each summary tuple and
    comparing them with the query quals; all pages in the range are returned
    in a lossy TID bitmap if the quals are consistent with the values in the
    summary tuple, otherwise not.  Normal index scans are not supported
    because these indexes do not store TIDs.

By nature, using a BRIN index for a query scan is a kind of mix between a
sequential scan and an index scan because what such an index scan is storing
a range of data for a given fixed number of data blocks. So this type of
index finds its advantages in very large relations that cannot sustain the
size of for example a btree where all values are indexed, and that is even
better with data that has a high ordering across the relation blocks. For
example let's take the case of a simple table where the data is completely
ordered across data pages like this one with 100 million tuples:

    =# CREATE TABLE brin_example AS SELECT generate_series(1,100000000) AS id;
    SELECT 100000000
    =# CREATE INDEX btree_index ON brin_example(id);
    CREATE INDEX
	Time: 239033.974 ms
    =# CREATE INDEX brin_index ON brin_example USING brin(id);
    CREATE INDEX
	Time: 42538.188 ms
    =# \d brin_example
    Table "public.brin_example"
     Column |  Type   | Modifiers
    --------+---------+-----------
     id     | integer |
    Indexes:
        "brin_index" brin (id)
        "btree_index" btree (id)

Note that the creation of the BRIN index was largely faster: it has less
index entries to write so it generates less traffic. By default, 128 blocks
are used to calculate a range of values for a single index entry, this can
be set with the new storage parameter pages\_per\_range using a WITH clause.

    =# CREATE INDEX brin_index_64 ON brin_example USING brin(id)
        WITH (pages_per_range = 64);
    CREATE INDEX
    =# CREATE INDEX brin_index_256 ON brin_example USING brin(id)
       WITH (pages_per_range = 256);
    CREATE INDEX
    =# CREATE INDEX brin_index_512 ON brin_example USING brin(id)
       WITH (pages_per_range = 512);
       CREATE INDEX

Having a look at the relation sizes, BRIN indexes are largely smaller in
size.

    =# SELECT relname, pg_size_pretty(pg_relation_size(oid))
        FROM pg_class WHERE relname LIKE 'brin_%' OR
	         relname = 'btree_index' ORDER BY relname;
        relname     | pg_size_pretty
    ----------------+----------------
     brin_example   | 3457 MB
     brin_index     | 104 kB
     brin_index_256 | 64 kB
     brin_index_512 | 40 kB
     brin_index_64  | 192 kB
     btree_index    | 2142 MB
    (6 rows)

Let's have a look at what kind of plan is generated then for scans using
the btree index and the BRIN index on the previous table.

    =# EXPLAIN ANALYZE SELECT id FROM brin_example WHERE id = 52342323;
                                          QUERY PLAN
    ---------------------------------------------------------------------------------
    Index Only Scan using btree_index on brin_example
          (cost=0.57..8.59 rows=1 width=4) (actual time=0.031..0.033 rows=1 loops=1)
       Index Cond: (id = 52342323)
       Heap Fetches: 1
     Planning time: 0.200 ms
     Execution time: 0.081 ms
    (5 rows)
	=# EXPLAIN ANALYZE SELECT id FROM brin_example WHERE id = 52342323;
                                           QUERY PLAN
	--------------------------------------------------------------------------------------
	 Bitmap Heap Scan on brin_example
           (cost=20.01..24.02 rows=1 width=4) (actual time=11.834..30.960 rows=1 loops=1)
       Recheck Cond: (id = 52342323)
       Rows Removed by Index Recheck: 115711
       Heap Blocks: lossy=512
       ->  Bitmap Index Scan on brin_index_512
	       (cost=0.00..20.01 rows=1 width=0) (actual time=1.024..1.024 rows=5120 loops=1)
              Index Cond: (id = 52342323)
     Planning time: 0.196 ms
     Execution time: 31.012 ms
	(8 rows)

The btree index is or course faster, in this case an index only scan is even
doable. Now remember that BRIN indexes are lossy, meaning that not all the
blocks fetched back after scanning the range entry may contain a target tuple.

A last thing to notice is that [pageinspect]
(http://www.postgresql.org/docs/devel/static/pageinspect.html) has been
updated with a set of functions to scan pages of a BRIN index:

    =# SELECT itemoffset, value
       FROM brin_page_items(get_raw_page('brin_index', 5), 'brin_index') LIMIT 5;
     itemoffset |         value
    ------------+------------------------
              1 | {35407873 .. 35436800}
              2 | {35436801 .. 35465728}
              3 | {35465729 .. 35494656}
              4 | {35494657 .. 35523584}
              5 | {35523585 .. 35552512}
    (5 rows)

With its first shot, BRIN indexes come with a set of operator classes able
to perform min/max calculation for each set of pages for most of the common
datatypes. The list is available [here]
(http://www.postgresql.org/docs/devel/static/brin-builtin-opclasses.html).
Note that the design of BRIN indexes make possible the implementation of
new operator classes with operations more complex than simple min/max, one
of the next operators that may show up would be for point and bounding box
calculations.
