---
author: Michael Paquier
comments: true
date: 2014-01-15 06:49:58+00:00
layout: post
slug: postgres-9-4-feature-highlight-lossyexact-pages-for-bitmap-heap-scan
title: 'Postgres 9.4 feature highlight: lossy/exact pages for bitmap heap scan'
wordpress_id: 2006
categories:
- PostgreSQL-2
tags:
- feature
- highlight
- 9.4
- bitmap
- scan
- new
- database
- exact
- gin
- gist
- index
- lossy
- pages
- postgres
- postgresql
---
When scanning a relation with a query with a bitmap heap scan and that the bitmap is not large enough to contain a reference to each tuple individually, bitmap heap scan switches to lossy mode where instead of the tuples relation pages are referenced in the bitmap. Then a Recheck condition on the heap is done to determine on each page which tuples to return, and to determine if a page is exact (tuples in the bitmap) or lossy (need to access to heap). The following commit adds an additional output in EXPLAIN ANALYZE to check the number of lossy and exact pages this bitmap heap scan used.

    commit 2bb1f14b89deacd1142b4a06bcb1a52a76270449
    Author: Robert Haas
    Date: Mon Jan 13 14:42:16 2014 -0500
 
    Make bitmap heap scans show exact/lossy block info in EXPLAIN ANALYZE.
 
    Etsuro Fujita

This can actually be used to calculate the amount of work\_mem that could be used to avoid any lossy pages. Here is how to do that based on a formula in tmb\_create@tidbitmap.c (pointed out by Etsuro Fujita on this thread of pgsql hackers).

    work_mem (bytes) = (Number of lossy pages + number of exact pages) *
      (MAXALIGN(sizeof(HASHELEMENT)) + MAXALIGN(sizeof(PagetableEntry))
      + sizeof(Pointer) + sizeof(Pointer))

And here is a simple test case usable showing how to trigger recheck on a bitmap heap scan. Using enable\_indexscan and enable\_seqscan is not that mandatory, it simply ensures that the planner falls back to the Bitmap scan.

    =# CREATE TABLE aa AS SELECT * FROM generate_series(1, 10000000) AS a ORDER BY random();
    SELECT 10000000
    =# CREATE INDEX aai ON aa(a);
    CREATE INDEX
    =# SET enable_indexscan=false;
    SET
    =# SET enable_seqscan=false;
    SET
    =# SET work_mem = 64kB;
    SET
    =# EXPLAIN ANALYZE SELECT * FROM aa WHERE a BETWEEN 100000 AND 200000;
                                                     QUERY PLAN
    --------------------------------------------------------------------------------------------------------------------------
    Bitmap Heap Scan on aa (cost=2078.64..47793.28 rows=97776 width=4) (actual time=30.810..2251.511 rows=100001 loops=1)
      Recheck Cond: ((a >= 100000) AND (a <= 200000))
      Rows Removed by Index Recheck: 8798475
      Heap Blocks: exact=338 lossy=39371
      -> Bitmap Index Scan on aai (cost=0.00..2054.20 rows=97776 width=0) (actual time=30.681..30.681 rows=100001 loops=1)
         Index Cond: ((a >= 100000) AND (a <= 200000))
     Total runtime: 2257.272 ms
    (7 rows)

In this case something like 40k pages have been fetched for the recheck condition. By applying the formula above, having approximately 3.2MB of work\_mem would be enough to fit all the tuples directly in memory.

    =# SET work_mem to '4MB';
    SET
    =# EXPLAIN ANALYZE SELECT * FROM aa WHERE a BETWEEN 100000 AND 200000;
                                                               QUERY PLAN
    --------------------------------------------------------------------------------------------------------------------------
    Bitmap Heap Scan on aa (cost=2078.64..47793.28 rows=97776 width=4) (actual time=43.296..220.716 rows=100001 loops=1)
      Recheck Cond: ((a >= 100000) AND (a <= 200000))
      Heap Blocks: exact=39709
      -> Bitmap Index Scan on aai (cost=0.00..2054.20 rows=97776 width=0) (actual time=31.390..31.390 rows=100001 loops=1)
         Index Cond: ((a >= 100000) AND (a <= 200000))
     Total runtime: 226.818 ms
    (6 rows)

Finally note the difference of time in execution. This additional output given by EXPLAIN ANALYZE is definitely worthy for development to understand how much a bitmap scan got lossy and how to adjust it.
