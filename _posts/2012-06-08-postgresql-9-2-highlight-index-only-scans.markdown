---
author: Michael Paquier
lastmod: 2012-06-08
date: 2012-06-08 02:43:49+00:00
layout: post
type: post
slug: postgresql-9-2-highlight-index-only-scans
title: 'PostgreSQL 9.2 highlight - Index-only scans'
categories:
- PostgreSQL-2
tags:
- 9.2
- postgres
- postgresql
- index

---

PostgreSQL 9.2 introduces a new performance feature called Index-Only scans, which was really something missing in core for performance of scan index.
Here is the commit that introduced the feature in core.

    commit a2822fb9337a21f98ac4ce850bb4145acf47ca27
    Author: Tom Lane <tgl@sss.pgh.pa.us>
    Date:   Fri Oct 7 20:13:02 2011 -0400

    Support index-only scans using the visibility map to avoid heap fetches.

    When a btree index contains all columns required by the query, and the
    visibility map shows that all tuples on a target heap page are
    visible-to-all, we don't need to fetch that heap page.  This patch depends
    on the previous patches that made the visibility map reliable.

    There's a fair amount left to do here, notably trying to figure out a less
    chintzy way of estimating the cost of an index-only scan, but the core
    functionality seems ready to commit.

    Robert Haas and Ibrar Ahmed, with some previous work by Heikki Linnakangas.

In a couple of words, what does this feature do?
Well, when reading data from a tuple in PostgreSQL which is part of an index, you need to perform an operation called an Index Scan.
This scan will return an index to tuples that might be part of the result. Why might? Because at the moment you are running your read query, the indexed tuples might have been modified by other transactions with a DML (INSERT, UPDATE, DELETE). As you are not sure that the data indexed is really the one you can use or not, you need to fetch the page of the table data and check if the wanted tuple row is visible to your transaction or not.

The commit message talks about "visibility map", which is a feature implemented since PostgreSQL 8.4, which allows to keep tracking of which pages contains only tuples that are visible to all the transactions (no data modified since latest vacuum cleanup for example). What this commit simply does is to check if the page that needs to be consulted is older than the transaction running.
If page is older, it means that the tuple on this page is visible and you do not need to fetch the page and the data, improving your performance due to the data you do not fetch directly from page. This operation of skipping the page scan is called an "Index-only scan".
If page is newer, well it means that the tuple to be consulted has been modified by another transaction and you need to fetch the latest information to protect data consistency. This is equivalent to a simple "Index Scan".

First, let's take a simple example to help understanding it (tests with PostgreSQL 9.2beta2).

    postgres=# CREATE TABLE aa (a int, b int, c int);
    CREATE TABLE
    postgres=# INSERT INTO aa VALUES
    postgres=# (1,generate_series(1,1000000),generate_series(1,1000000));
    INSERT 0 1000000
    postgres=# CREATE INDEX aa_i ON aa (a,b,c);
    CREATE INDEX
    postgres=# SELECT a,b,c FROM aa WHERE a = 1 order by b;

In the case of the SELECT query on table aa, the index you would instinctively define is on columns a and b. The SELECT query is performing a scan on those columns values, so it is enough to have an index on them and fetch related data directly.
However, you might also consider to define an index directly on columns a, b and c, and then use the Index-only scan feature to avoid having to fetch all the tuples in your table if not necessary. One of the disadvantages is that you create a larger index, so you should consider case by case if your performance gain is worth using this functionality or not.

Just for reference, the EXPLAIN plan changes as follows regarding the cases for the two cases.

    postgres=# EXPLAIN SELECT a,b,c FROM aa WHERE a = 1 ORDER BY b;
                                        QUERY PLAN                                    
    ----------------------------------------------------------------------------------
    Index Only Scan using aa_indexonly on aa  (cost=0.00..169.29 rows=5000 width=12)
      Index Cond: (a = 1)
    (2 rows)
    postgres=# SET enable_indexonlyscan TO false;
    SET
    postgres=# EXPLAIN SELECT a,b,c FROM aa WHERE a = 1 ORDER BY b;
                                    QUERY PLAN                                
    --------------------------------------------------------------------------
    Index Scan using aa_i on aa  (cost=0.00..45416.85 rows=1000000 width=12)
      Index Cond: (a = 1)
    (2 rows)

enable_indexonlyscan is a switch that can be used to control this feature. The difference between the two plans is the use of the keyword "Only".

Then, what about the performance gain with this feature? Let's use the example above of table aa with 10,000,000 rows inserted. (Note: a scan on so many tuples is not recommended in an application, this example is only used to show the performance of Index-only scans),

    postgres=# insert into aa values 
    postgres=# (1,generate_series(1,10000000),generate_series(1,10000000));
    INSERT 0 10000000
    postgres=# vacuum;
    VACUUM
    postgres=# EXPLAIN ANALYZE SELECT a,b,c FROM aa WHERE a = 1 ORDER BY b;
                                                                  QUERY PLAN                                                               
    ---------------------------------------------------------------------------------------------------------------------------------------
    Sort  (cost=61745.60..61870.60 rows=50000 width=12) (actual time=8108.138..9426.384 rows=10000000 loops=1)
      Sort Key: b
      Sort Method: external sort  Disk: 215064kB
      ->  Bitmap Heap Scan on aa  (cost=1175.15..56985.69 rows=50000 width=12) (actual time=1113.548..2937.281 rows=10000000 loops=1)
          Recheck Cond: (a = 1)
          ->  Bitmap Index Scan on aa_i  (cost=0.00..1162.65 rows=50000 width=0) (actual time=1111.961..1111.961 rows=10000000 loops=1)
              Index Cond: (a = 1)
     **Total runtime: 9849.555 ms**
    (8 rows)
    postgres=# SET enable_indexonlyscan TO true;
    SET
    postgres=# EXPLAIN ANALYZE SELECT a,b,c FROM aa WHERE a = 1 ORDER BY b;
                                                                 QUERY PLAN                                                              
    -------------------------------------------------------------------------------------------------------------------------------------
    Index Only Scan using aa_i on aa  (cost=0.00..329041.35 rows=10000097 width=12) (actual time=0.039..1701.827 rows=10000000 loops=1)
    Index Cond: (a = 1)
    Heap Fetches: 0
     **Total runtime: 2092.925 ms**
    (4 rows)

It took 5 times less to perform the scan on the whole table by scanning only index, and no tuples have been fetched in the case of Index-only scan.
Once again and to conclude this post, this feature is a great performance achievement. But never forget to consider the balance between creating larger indexes and the performance Index-Only scans will make you gain.
