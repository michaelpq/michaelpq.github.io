---
author: Michael Paquier
lastmod: 2013-03-14
date: 2013-03-14 06:08:34+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-writable-foreign-tables
title: 'Postgres 9.3 feature highlight - writable foreign tables'
categories:
- PostgreSQL-2
tags:
- 9.3
- fdw
- postgres
- postgresql
- dml

---

A new set of APIs for foreign data wrappers has been added to allow writable operations on foreign sources. This feature has been committed by Tom Lane a couple of days ago.

    commit 21734d2fb896e0ecdddd3251caa72a3576e2d415
    Author: Tom Lane <tgl@sss.pgh.pa.us>
    Date:   Sun Mar 10 14:14:53 2013 -0400
    
    Support writable foreign tables.
    
    This patch adds the core-system infrastructure needed to support updates
    on foreign tables, and extends contrib/postgres_fdw to allow updates
    against remote Postgres servers.  There's still a great deal of room for
    improvement in optimization of remote updates, but at least there's basic
    functionality there now.
    
    KaiGai Kohei, reviewed by Alexander Korotkov and Laurenz Albe, and rather
    heavily revised by Tom Lane.

Based on the [documentation](http://www.postgresql.org/docs/devel/static/fdw-callbacks.html#FDW-CALLBACKS-UPDATE), the implementation is still very basic as nothing is done with clause shippability. Just to give some notions about that: roughly a clause in a SELECT query (LIMIT, OFFSET, GROUP BY, HAVING, ORDER BY, etc.) is shippable if this clause can be entirely evaluated on remote server, making less processing happening on local server, and reducing the tuple selectivity. A direct consequence of clause shippability limitation is that UPDATE and DELETE queries can take quite a long time if they are run on many rows because query is run in two steps:

  * Scan remote table and fetch back to local server the tuples to be manipulated
  * Process UPDATE or DELETE based on the tuples fetched

INSERT does not need such scan as in this case new data is simply sent to the remote table, the tuple values being computed before sending the query (even for immutable functions). Not really performant but it is the safest approach. Postgres-XC has similar and more advanced features for foreign DDL planning and execution in its core (some of them implemented by me), have a look for example at [this article](/postgresql-2/complex-dml-queries-and-clause-push-down-in-postgres-xc/) I wrote a while ago.

It is possible to test writable foreign tables with postgres\_fdw as it has been extended to support this new feature. So let's give it a try with two postgres servers using ports 5432 and 5433. Server with port 5432 has postgres\_fdw installed and will interact with the remote server running under port 5433. In order to get the basics of postgres\_fdw, you can refer to [this article](/postgresql-2/postgres-9-3-feature-highlight-postgres_fdw/) written a couple of weeks ago.

Now, it is time to test the feature. First let's create a table on remote server.

    $ psql -p 5433 -c "CREATE TABLE aa_remote (a int, b int)" postgres
    CREATE TABLE

Then it is necessary to create a foreign table on the local server.

    postgres=# CREATE SERVER postgres_server FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host 'localhost', port '5433', dbname 'postgres');
    CREATE SERVER
    postgres=# CREATE USER MAPPING FOR PUBLIC SERVER postgres_server OPTIONS (password '');
    CREATE USER MAPPING
    postgres=# CREATE FOREIGN TABLE aa_foreign (a int, b int) SERVER postgres_server OPTIONS (table_name 'aa_remote'); 
    CREATE FOREIGN TABLE

Then let's test the new feature by performing some DML operations on the foreign table from local server.

    postgres=# INSERT into aa_foreign values (1,2);
    INSERT 0 1
    postgres=# select * from aa_foreign;
     a | b 
    ---+---
     1 | 2
    (1 row)
    postgres=# update aa_foreign set b = 3;
    UPDATE 1
    postgres=# select * from aa_foreign;
     a | b 
    ---+---
     1 | 3
    (1 row)

Everything is going well on local side, and on remote side what happened?

    $ psql -p 5433 -c 'SELECT * FROM aa_remote' --dbname postgres
     a | b 
    ---+---
     1 | 3
    (1 row)

So the data of the remote table has been correctly changed from local server.

Just before the tests, I explained that a scan is done for UPDATE and DELETE before actually running the DML, you can get more details about that with EXPLAIN.

    postgres=# explain verbose update aa_foreign set b = 3;
                                        QUERY PLAN                                     
    -----------------------------------------------------------------------------------
     Update on public.aa_foreign  (cost=100.00..182.27 rows=2409 width=10)
        Remote SQL: UPDATE public.aa_remote SET b = $2 WHERE ctid = $1
        ->  Foreign Scan on public.aa_foreign  (cost=100.00..182.27 rows=2409 width=10)
            Output: a, 3, ctid
            Remote SQL: SELECT a, NULL, ctid FROM public.aa_remote FOR UPDATE
    (5 rows)

In the case of postgres\_fdw, selectivity of tuple is done with ctid of tuple, which ensures tuple uniqueness. Note that if you implement your own foreign data wrapper, you might need to use columns having primary keys for selectivity of tuples.

There are also a couple of things to be aware of when using this feature.

  * There are risk of data incompatibility for data formatted with GUC parameters. This has been mentionned in the community but try for example to manipulate servers with different settings of datesyle...
  * Transactions are open on remote server using repeatable read.
  * UPDATE and DELETE can be costly if scan is done with a good-old-fashioned sequential scan, but well that's a known thing
  * Things I forgot...
