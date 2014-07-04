---
author: Michael Paquier
comments: true
lastmod: 2014-07-04
date: 2014-07-04 13:47:29+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-process-tracking-cluster-name
title: 'Postgres 9.5 feature highlight: WHERE clause pushdown in subqueries with window functions'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- 9.5
- new
- feature
- clause
- window
- subquery
- query
- function
- pushdown
- performance
- data
- population
- fast
---
Postgres 9.5 is going to improve the performance of subqueries using window
functions by allowing the pushdown of WHERE clauses within them. Here is a
commit, done during commit fest 1, that is the origin of this improvement:

    commit d222585a9f7a18f2d793785c82be4c877b90c461
    Author: Tom Lane <tgl@sss.pgh.pa.us>
    Date:   Fri Jun 27 23:08:08 2014 -0700

    Allow pushdown of WHERE quals into subqueries with window functions.

    We can allow this even without any specific knowledge of the semantics
    of the window function, so long as pushed-down quals will either accept
    every row in a given window partition, or reject every such row.  Because
    window functions act only within a partition, such a case can't result
    in changing the window functions' outputs for any surviving row.
    Eliminating entire partitions in this way obviously can reduce the cost
    of the window-function computations substantially.

    David Rowley, reviewed by Vik Fearing; some credit is due also to
    Thomas Mayer who did considerable preliminary investigation.

The pushdown of the WHERE qual is done only if two conditions are
satisfied:

  * Only the partitioning columns are referenced
  * The qual contains no volatile functions

Let's have a look at how things are improved by using a simple data
set: a list of individuals referenced by an ID, with information about
the city where they live and their respective age (the authorities lacked
imagination for the city names).

    =# CREATE TABLE population (
         person_id serial,
         age int,
         city text);
    CREATE TABLE
    =# INSERT INTO population (age, city)
         SELECT round(random() * 100),
                'city ' || round(random() * 200)
         FROM generate_series(1, 1000000);
    INSERT 0 1000000

Now, here is a query that evaluates the average, minimum and maximum age
of the cities where the population is living. If 9.4, this query returns
the following plan:

    =# EXPLAIN SELECT * FROM
         (SELECT city,
            avg(age) OVER (PARTITION BY city) avg_age,
            min(age) OVER (PARTITION BY city) min_age,
            max(age) OVER (PARTITION BY city) max_age
          FROM population) age_all
       WHERE city in ('city 26', 'city 47')
       GROUP BY avg_age, city, min_age, max_age;
                                             QUERY PLAN
     ---------------------------------------------------------------------------------------------
      HashAggregate  (cost=184834.34..184844.29 rows=995 width=48)
       Group Key: age_all.avg_age, age_all.city, age_all.min_age, age_all.max_age
        ->  Subquery Scan on age_all  (cost=149734.84..184734.84 rows=9950 width=48)
              Filter: (age_all.city = ANY ('{"city 26","city 47"}'::text[]))
              ->  WindowAgg  (cost=149734.84..172234.84 rows=1000000 width=12)
                    ->  Sort  (cost=149734.84..152234.84 rows=1000000 width=12)
                          Sort Key: population.city
                          ->  Seq Scan on population  (cost=0.00..15896.00 rows=1000000 width=12)
      Planning time: 0.227 ms
     (9 rows)

As you can notice, a sequential scan is done by the subquery on the whole
table "Seq Scan on population", while the WHERE clause is applied after
generating the results through a costly sort operation on all the rows. This
query took 2 seconds to run on a machine of the author of this article
(sort did not spill on disk as work_mem was set high enough).

     =# SELECT * FROM
         (SELECT city,
            avg(age) OVER (PARTITION BY city) avg_age,
            min(age) OVER (PARTITION BY city) min_age,
            max(age) OVER (PARTITION BY city) max_age
          FROM population) age_all
        WHERE city in ('city 26', 'city 47')
        GROUP BY avg_age, city, min_age, max_age;
       city   |       avg_age       | min_age | max_age
     ---------+---------------------+---------+---------
      city 47 | 49.6150433555152248 |       0 |     100
      city 26 | 49.7953169156237384 |       0 |     100
     (2 rows)
     Time: 2276.422 ms

In Postgres 9.5, here is the plan obtained for the same query (plan has
been reformated a bit here to fit on this blog page):

                                            QUERY PLAN
     ------------------------------------------------------------------------------------
      HashAggregate  (cost=15171.49..15178.33 rows=684 width=72)
        Group Key: avg(population.age) OVER (?),
                   population.city,
                   min(population.age) OVER (?),
                   max(population.age) OVER (?)
        ->  WindowAgg  (cost=14880.83..15034.71 rows=6839 width=36)
              ->  Sort  (cost=14880.83..14897.93 rows=6839 width=36)
                    Sort Key: population.city
                    ->  Seq Scan on population  (cost=0.00..14445.20 rows=6839 width=36)
                          Filter: (city = ANY ('{"city 26","city 47"}'::text[]))
     Planning time: 0.203 ms
    (6 rows)

Things are getting better, the WHERE clause is evaluated within the
subquery, drastically reducing the cost of the sort by reducing the
number of tuples selected. Running this query takes as well only 300ms,
which is an interesting improvement compared to the pre-commit period.
