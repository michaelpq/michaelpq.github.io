---
author: Michael Paquier
lastmod: 2013-08-06
date: 2013-08-06 08:54:43+00:00
layout: post
type: post
slug: text-search-with-a-commonly-known-book
title: 'Text search with a commonly-known book'
categories:
- PostgreSQL-2
tags:
- knn
- pg_trgm
- postgres
- postgresql
- text

---
Just yesterday on hackers, [a post by Kevin Grittner](https://www.postgresql.org/message-id/1375457112.43393.YahooMailNeo@web162905.mail.bf1.yahoo.com) mentionned using [pg\_trgm](https://www.postgresql.org/docs/current/static/pgtrgm.html) to find similar sentences in a text. His example involved using "War and Peace" (which is under the public domain). When trying to tune queries, you might want to use always the same set of examples to actually analyze easily if there is a potential gain for your query. Just by thinking about that, using classic books available directly is a great way for people to evaluate the performance of a text search algorithm or a given application implementation. This could be even useful to compare the performance of several database systems regarding index scans because the data is the same, only counts the search speed, assuming that all the systems have been tuned to scan data the same way (for example all data on memory).

By the way, there are many books available in the public domain (just do a bit of googling) that you can use for this purpose. In the case of Postgres, here is an example of text search using "Les Miserables" of Victor Hugo. Let's first create its table, in this case with one row per line.

    postgres=# CREATE TABLE les_miserables (num serial, line text);
    CREATE TABLE
    postgres=# COPY les_miserables (line) FROM '$FOLDER_OF_FILE/les_miserables.txt';
    COPY 70761

This gives a table with 70k rows ready to be scanned.

Before playing with text similarity, just be sure to install pg\_trgm from the contrib modules.

    postgres=# CREATE EXTENSION pg_trgm;
    CREATE EXTENSION

Now what happens if you scan the text if it has no gist index?

    postgres=# SELECT * FROM les_miserables order by line <-> 'Cosette Valjean miserable' limit 4;
       num | line
    -------+-------------------------------------------------------------------
     70086 | "Cosette!" said Jean Valjean.
     44423 | that Jean Valjean said to Cosette:--
     65867 | Cosette and Aunt Gillenormand, M. Gillenormand and Jean Valjean.
     70132 | I am a miserable man, I shall never see Cosette again,' and I was
    (4 rows)
    postgres=# EXPLAIN ANALYZE SELECT * FROM les_miserables order by line <-> 'Cosette Valjean miserable' limit 4;
                                                                  QUERY PLAN
    -----------------------------------------------------------------------------------------------------------------------------------
    Limit (cost=2654.93..2654.94 rows=4 width=50) (actual time=1312.671..1312.673 rows=4 loops=1)
      -> Sort (cost=2654.93..2831.83 rows=70761 width=50) (actual time=1312.669..1312.669 rows=4 loops=1)
         Sort Key: ((line <-> 'Cosette Valjean miserable'::text))
         Sort Method: top-N heapsort Memory: 25kB
         -> Seq Scan on les_miserables (cost=0.00..1593.51 rows=70761 width=50) (actual time=0.085..1281.985 rows=70761 loops=1)
      Total runtime: 1312.722 ms
    (6 rows)

In this case the sequential scan of the table is really costly, and the query needs more than 1s to run.

Now let's introduce a gist index...

    postgres=# CREATE INDEX les_miserables_idx ON les_miserables USING gist (line gist_trgm_ops);
    CREATE INDEX
    postgres=# EXPLAIN ANALYZE SELECT * FROM les_miserables order by line <-> 'Cosette Valjean miserable' LIMIT 4;
                                                                      QUERY PLAN
    ----------------------------------------------------------------------------------------------------------------------------------------------------
    Limit (cost=0.28..0.93 rows=4 width=50) (actual time=82.240..82.313 rows=4 loops=1)
    -> Index Scan using les_miserables_idx on les_miserables (cost=0.28..11483.50 rows=70761 width=50) (actual time=82.238..82.311 rows=4 loops=1)
       Order By: (line <-> 'Cosette Valjean miserable'::text)
    Total runtime: 83.362 ms
    (4 rows)

And the query now takes 83ms to run instead of 1.3s. Note that the planner gives preference to an index scan instead of a sequential scan thanks to the LIMIT clause specified in the query.
