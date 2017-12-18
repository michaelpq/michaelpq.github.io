---
author: Michael Paquier
lastmod: 2017-12-17
date: 2017-12-17 02:40:51+00:00
layout: post
type: post
slug: partition-information
title: 'Getting more Information about Partitions'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- partition
- list
- hash
- items
- split
- elements

---

A couple of days back a thread has showed up on pgsql-hackers to discuss
about the possibility of a function scanning all the partitions of a chain
to get its size. The thread is [here](https://www.postgresql.org/message-id/495cec7e-f8d9-7e13-4807-90dbf4eec4ea@lab.ntt.co.jp).

Without waiting for the result of this thread, even if there is no in-core
function to fetch a complete list of partitions or even its size, it is
perfectly possible to do so using at SQL level using a WITH RECURSIVE
function. Imagine for example the following set of tables (Postgres
documentation has some
[nice examples](https://www.postgresql.org/docs/devel/static/sql-createtable.html)
by the way), with a partition chain. There is a parent relation like this
one for a population:

    =# CREATE TABLE population (
         user_id      bigserial not null,
         family_name  text not null,
         first_name   text not null,
         age          int
       ) PARTITION BY LIST (left(lower(family_name), 1));

This tracks any tuples inserted on the parent using the first letter of the
family name. And then let's create some leaf partitions. However you suspect
that the population is going to be rather large for some letters, so you would
like as well to divide each leaf-partition into another set of leafs by
separating things using the population age. Then the set of leaves can be
set as follows:

    =# CREATE TABLE population_s PARTITION OF population
       FOR VALUES IN ('s');
    CREATE TABLE
    =# CREATE TABLE population_t PARTITION OF population
       FOR VALUES in ('t') PARTITION BY RANGE (age);
    CREATE TABLE

In this case we assume that the population whose family name begins by
's' can use a single partition, while for 't' things had better be splitted
more. Still you are not completely done yet, let's define more partitions
to divide by age the population whose family name begins by 't':

    =# CREATE TABLE population_t_10_20 PARTITION OF population_t
       FOR VALUES FROM (10) TO (20);
    CREATE TABLE
    =# CREATE TABLE population_t_20_30 PARTITION OF population_t
       FOR VALUES FROM (20) TO (30);
    CREATE TABLE

Now let's create the population of this young country, with data like
that inserted into the parent relation:

    =# INSERT INTO population (family_name, first_name, age) VALUES
         ('Tanaka', 'Tom', 20),
         ('Theory', 'Suzy', 13),
         ('Suzuki', 'Hidetoshi', 80);
    =# SELECT family_name, first_name, age FROM population ORDER BY family_name;
     family_name | first_name | age
    -------------+------------+-----
     Suzuki      | Hidetoshi  |  80
     Tanaka      | Tom        |  20
     Theory      | Suzy       |  13
    (3 rows)

Of course each leaf partition has the data it should have:

    =# SELECT family_name, first_name, age FROM population_s;
     family_name | first_name | age
    -------------+------------+-----
     Suzuki      | Hidetoshi  |  80
    (1 row)
    =# SELECT family_name, first_name, age FROM population_t_10_20;
     family_name | first_name | age
    -------------+------------+-----
     Theory      | Suzy       |  13
    (1 row)
    =# SELECT family_name, first_name, age FROM population_t_20_30;
     family_name | first_name | age
    -------------+------------+-----
     Tanaka      | Tom        |  20
    (1 row)

Now comes the real meat of this blog post. There is no direct way to get
the partition list with a dedicated system function. One can of course
design a simple extension to do so at C-level, still it can be more simple
for some users to rely on a more native solution using a WITH RECURSIVE
clause. So here is a query to get some information about a partition chain:

    =# WITH RECURSIVE partition_info
          (relid,
           relname,
           relsize,
           relispartition,
           relkind) AS (
        SELECT oid AS relid,
               relname,
               pg_relation_size(oid) AS relsize,
               relispartition,
               relkind
        FROM pg_catalog.pg_class
	WHERE relname = 'population' AND
	      relkind = 'p'
      UNION ALL
        SELECT
             c.oid AS relid,
             c.relname AS relname,
             pg_relation_size(c.oid) AS relsize,
             c.relispartition AS relispartition,
             c.relkind AS relkind
        FROM partition_info AS p,
             pg_catalog.pg_inherits AS i,
             pg_catalog.pg_class AS c
        WHERE p.relid = i.inhparent AND
             c.oid = i.inhrelid AND
             c.relispartition
      )
    SELECT * FROM partition_info;
     relid |      relname       | relsize | relispartition | relkind
    -------+--------------------+---------+----------------+---------
     16410 | population         |       0 | f              | p
     16417 | population_s       |    8192 | t              | r
     16424 | population_t       |       0 | t              | p
     16431 | population_t_10_20 |    8192 | t              | r
     16445 | population_t_20_30 |    8192 | t              | r
    (5 rows)

That's a barbarious query, still here is how to decrypt it based on the
information of the catalog tables:

  * pg\_class.relkind tracks with 'p' if the relation is a parent
  partition or not. When using 'r' the relation can store data.
  * pg\_class.relispartition defines if a relation is a leaf partition
  from a parent.
  * The link between a parent and its leaf is defined in pg\_inherits,
  where inhparent tracks the relation OID of the parent and inhrelid
  the relation OID of the leaf.

Using a base like that, it is easy to get for example the complete on-disk
size of a partition using other catalog functions like pg\_relation\_size().
Using for example a simple aggregate with the previous query for the most outer
query, here is the result:

  =# -- [Insert WITH RECURSIVE portion of previous long query here]
     SELECT pg_size_pretty(sum(relsize)) AS total_size FROM partition_info;
      total_size
    ------------
     24 kB
    (1 row)

This gives you the total partition size (well without the indexes and such
but this is let as a simple exercise for the reader). In order to adapt
it to your own partition set, changing the relation name used in the inner
query is necessary, so wrapping that in a function may be useful. Note that
this is perfectly compatible with at least Postgres 10.
