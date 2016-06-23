---
author: Michael Paquier
lastmod: 2013-03-08
date: 2013-03-08 02:11:14+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-materialized-views
title: 'Postgres 9.3 feature highlight - Materialized views'
categories:
- PostgreSQL-2
tags:
- '9.3'
- automatic
- data
- feature
- highlight
- materialized
- new
- open source
- postgres
- postgresql
- refresh
- relation
- table
- unlogged
- view
---

PostgreSQL 9.3 comes with a pretty cool feature called [materialized views](http://www.postgresql.org/docs/devel/static/rules-materializedviews.html). It has been created by Kevin Grittner and committed by the same person not so long ago.

    commit 3bf3ab8c563699138be02f9dc305b7b77a724307
    Author: Kevin Grittner <kgrittn@postgresql.org>
    Date:   Sun Mar 3 18:23:31 2013 -0600
    
    Add a materialized view relations.
    
    A materialized view has a rule just like a view and a heap and
    other physical properties like a table.  The rule is only used to
    populate the table, references in queries refer to the
    materialized data.
    
    This is a minimal implementation, but should still be useful in
    many cases.  Currently data is only populated "on demand" by the
    CREATE MATERIALIZED VIEW and REFRESH MATERIALIZED VIEW statements.
    It is expected that future releases will add incremental updates
    with various timings, and that a more refined concept of defining
    what is "fresh" data will be developed.  At some point it may even
    be possible to have queries use a materialized in place of
    references to underlying tables, but that requires the other
    above-mentioned features to be working first.
    
    Much of the documentation work by Robert Haas.
    Review by Noah Misch, Thom Brown, Robert Haas, Marko Tiikkaja
    Security review by KaiGai Kohei, with a decision on how best to
    implement sepgsql still pending.

What is a materialized view? In short, it is the mutant of a table and a view. A view is a projection of data in a given relation and has no storage. A table is well... A table...
Between that, a materialized view is a projection of table data and has its own storage. It uses a query to fetch its data like a view, but this data is stored like a common table. The materialized view can also be refreshed with updated data by running once again the query it uses for its projection, or have its data truncated. In the last case it is left in an non-scannable state. Also, as a materialized view has its proper storage, it can use tablespaces and its own indexes. Note that it can also be an unlogged relation.

This feature introduces four new SQL commands:

  * [CREATE MATERIALIZED VIEW](http://www.postgresql.org/docs/devel/static/sql-creatematerializedview.html)
  * [ALTER MATERIALIZED VIEW](http://www.postgresql.org/docs/devel/static/sql-altermaterializedview.html)
  * [DROP MATERIALIZED VIEW](http://www.postgresql.org/docs/devel/static/sql-dropmaterializedview.html)
  * [REFRESH MATERIALIZED VIEW](http://www.postgresql.org/docs/devel/static/sql-refreshmaterializedview.html)

CREATE, ALTER and DROP are common DDL commands here to manipulate the definition of materialized views. What is important here is the new command REFRESH (its name has been a long debate inside the community). This command can be used to update the materialized view with fresh data by running once again the scanning query. Note that REFRESH can also be used to *truncate* (not really though) the data of the relation by running it with the clause WITH NO DATA.

Materialized views have their own advantages in many scenarios: faster access to data than needs to be brought from a remote server (read a file on postgres server through file\_fdw, etc.), using data that needs to be refreshed periodically (cache system), projecting data with embedded ORDER BY from a large table, running an expensive join in background periodically, etc.

I can also imagine some nice combinations with data refresh and custom background workers. Who said that automatic data refresh on a materialized view was not possible?

Now let's have a look at how it works.

    postgres=# CREATE TABLE aa AS SELECT generate_series(1,1000000) AS a;
    SELECT 1000000
    postgres=# CREATE VIEW aav AS SELECT * FROM aa WHERE a <= 500000;
    CREATE VIEW
    postgres=# CREATE MATERIALIZED VIEW aam AS SELECT * FROM aa WHERE a <= 500000;
    SELECT 500000

Here is the size that each relation uses.

    postgres=# SELECT pg_relation_size('aa') AS tab_size, pg_relation_size('aav') AS view_size, pg_relation_size('aam') AS matview_size;
     tab_size | view_size | matview_size 
    ----------+-----------+--------------
     36249600 |         0 |     18137088
    (1 row)

A materialized view uses storage (here 18M), as much as it needs to store the data it fetched from its parent table (with size of 36M) when running the view query.

The refresh of a materialized view can be controlled really easily.

    postgres=# DELETE FROM aa WHERE a <= 500000;
    DELETE 500000
    postgres=# SELECT count(*) FROM aam;
     count  
    --------
     500000
    (1 row)
    postgres=# REFRESH MATERIALIZED VIEW aam;
    REFRESH MATERIALIZED VIEW
    postgres=# SELECT count(*) FROM aam;
     count 
    -------
         0
    (1 row)

The new status of table aa is effective on its materialized view aam only once REFRESH has been kicked. Note that at the time of this post, REFRESH uses an exclusive lock (ugh...).

A materialized view can also be set as not scannable thanks to the clause WITH NO DATA of REFRESH.

    postgres=# REFRESH MATERIALIZED VIEW aam WITH NO DATA;
    REFRESH MATERIALIZED VIEW
    postgres=# SELECT count(*) FROM aam;
    ERROR:  materialized view "aam" has not been populated
    HINT:  Use the REFRESH MATERIALIZED VIEW command.

There is a new catalog table to help you find the current state of materialized views called pg\_matviews.

    postgres=# SELECT matviewname, isscannable FROM pg_matviews;
     matviewname | isscannable 
    -------------+-------------
     aam         | f
    (1 row)

It is also not possible to run DML queries on it. This makes sense as the data this view has might not reflect the current state of its parent relation(s). On the contrary, a simple view runs its underlying query each time it is needed, so a parent table could be modified through it (per se [updatable views](/postgresql-2/postgres-9-3-feature-highlight-auto-updatable-views/)).

    postgres=# INSERT INTO aam VALUES (1);
    ERROR:  cannot change materialized view "aam"
    postgres=# UPDATE aam SET a = 5;
    ERROR:  cannot change materialized view "aam"
    postgres=# DELETE FROM aam;
    ERROR:  cannot change materialized view "aam"

Now, a couple of words about performance improvement and degradation you can have with materialized views as you can manipulate indexes on those relations. For example, it is easily possible to improve queries on the materialized views without caring about the schema of its parent relations.

    postgres=# EXPLAIN ANALYZE SELECT * FROM aam WHERE a = 1;
                                                QUERY PLAN                                            
    --------------------------------------------------------------------------------------------------
     Seq Scan on aam  (cost=0.00..8464.00 rows=1 width=4) (actual time=0.060..155.934 rows=1 loops=1)
       Filter: (a = 1)
       Rows Removed by Filter: 499999
     Total runtime: 156.047 ms
    (4 rows)
    postgres=# CREATE INDEX aam_ind ON aam (a);
    CREATE INDEX
    postgres=# EXPLAIN ANALYZE SELECT * FROM aam WHERE a = 1;
                                                        QUERY PLAN                                                    
    ------------------------------------------------------------------------------------------------------------------
     Index Only Scan using aam_ind on aam  (cost=0.42..8.44 rows=1 width=4) (actual time=2.096..2.101 rows=1 loops=1)
       Index Cond: (a = 1)
       Heap Fetches: 1
     Total runtime: 2.196 ms
    (4 rows)

Take care also that indexes and constraint (materialized views can have constraints!) of the parent relation are not copied with the materialized view. For example, a fast query scanning some table's primary key might finish with a deadly sequential scan if it is run on an underlying materialized view based on this table.

    postgres=# INSERT INTO bb VALUES (generate_series(1,100000));
    INSERT 0 100000
    postgres=# EXPLAIN ANALYZE SELECT * FROM bb WHERE a = 1;
                                                       QUERY PLAN                                                    
    -----------------------------------------------------------------------------------------------------------------
     Index Only Scan using bb_pkey on bb  (cost=0.29..8.31 rows=1 width=4) (actual time=0.078..0.080 rows=1 loops=1)
       Index Cond: (a = 1)
       Heap Fetches: 1
     Total runtime: 0.159 ms
    (4 rows)
    postgres=# CREATE MATERIALIZED VIEW bbm AS SELECT * FROM bb;
    SELECT 100000
    postgres=# EXPLAIN ANALYZE SELECT * FROM bbm WHERE a = 1;
                                                QUERY PLAN                                             
    ---------------------------------------------------------------------------------------------------
     Seq Scan on bbm  (cost=0.00..1776.00 rows=533 width=4) (actual time=0.144..41.873 rows=1 loops=1)
       Filter: (a = 1)
       Rows Removed by Filter: 99999
     Total runtime: 41.935 ms
    (4 rows)

Such designs are of course not recommended on a production system, only be aware that bad designs will badly impact your application performance (that's always the case btw).

It is really a nice thing to have particularly for caching applications! So enjoy!
