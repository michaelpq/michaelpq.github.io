---
author: Michael Paquier
comments: true
lastmod: 2014-01-28
date: 2014-01-28 02:54:18+00:00
layout: post
type: post
slug: global-sequences-with-postgres_fdw-and-postgres-core
title: 'Global sequences with postgres_fdw and Postgres core'
wordpress_id: 2006
categories:
- PostgreSQL-2
tags:
- 9.3
- connection
- feature
- foreign data
- global
- open source
- postgres
- postgresql
- postgres_fdw
- primary key
- relation
- remote
- sequence
- server
- table
- view
- wrapper
---
The new foreign data wrapper available with PostgreSQL core called [postgres\_fdw](http://www.postgresql.org/docs/devel/static/postgres-fdw.html) (to basically query foreign Postgres servers and fetch back data locally) makes possible a couple of interesting things with a little bit of imagination. First, you need to be aware that postgres\_fdw can query all types of relations on a remote server: not only tables but also materialized views, sequences (with SELECT * FROM seqname) and even views.

Views are defined based on a query that is executed each time the view is queried. This SQL query can as well use functions, functions that would be executed each time the view is touched. Now, let's take the case of a foreign table on server A going through postgres\_fdw that queries a view on a remote server B. This view executes a function (and even other things) on server B, and this function result is sent back to server A with the foreign table. Using this simple concept, and you have a huge set of possibilities in front of you. And some of them permit the implementation of some data sharding across multiple nodes, or even what interests us in this post, the concept of a global sequence.

What could be called a global sequence is a sequence able to feed multiple Postgres servers with unique and different values. This is something that you can find for example in the fork of Postgres called [Postgres-XC](https://sourceforge.net/apps/mediawiki/postgres-xc/index.php?title=Main_Page) (providing synchronous multi-master capabilities), where a sequence is able to feed multiple cluster nodes with unique values, particularly useful for a SERIAL column for example.

Doing something similar with only Postgres and postgres\_fdw is actually possible, and here is how to do it... In the case of this post, server A and B are both located on the same machine, listening respectively to ports 5432 and 5433. Server B will manage the sequence that server A will be able to query to get unique values. First, we need to create on server B the view that will be used for the foreign table of server A.

    =# CREATE SEQUENCE seq;
    CREATE SEQUENCE
    =# CREATE VIEW seq_view AS SELECT nextval('seq') as a;
    CREATE VIEW

So the view "seq\_view" returns a row with a single column of type bigint whose value is the next value of sequence "seq". Simple, no?

Now, let's create the foreign table on server A that queries seq\_view (Don't forget to create the extension postgres\_fdw!).

    =# CREATE EXTENSION postgres_fdw;
    CREATE EXTENSION
    =# CREATE SERVER postgres_server
    -# FOREIGN DATA WRAPPER postgres_fdw
    -# OPTIONS (host 'localhost', port '5433', dbname 'postgres');
    CREATE SERVER
    =# CREATE USER MAPPING FOR PUBLIC SERVER postgres_server OPTIONS (password '');
    CREATE USER MAPPING
    =# CREATE FOREIGN TABLE foreign_seq_table (a bigint)
    -# SERVER postgres_server OPTIONS (table_name 'seq_table');
    CREATE FOREIGN TABLE

So what we have now is the possibility to query the same sequence across two servers:

    $ psql -At -p 5432 -c "select * from foreign_seq_table"
    1
    $ psql -At -p 5433 -c "select * from seq_view"
    2
    $ psql -At -p 5432 -c "select * from foreign_seq_table"
    3
    $ psql -At -p 5433 -c "select * from seq_view"
    4

It is possible to do better than that, for example by creating a function of the type foreign\_seq\_nextval on server A, able to query directly the next value of the sequence on a remote server B.

    =# CREATE FUNCTION foreign_seq_nextval() RETURNS bigint AS
    -# 'SELECT a FROM foreign_seq_table;' LANGUAGE SQL;
    CREATE FUNCTION

OK, this is in SQL and could be cleaner... But by using that it is possible to query directly a sequence on a foreign server for a fresh, unique value for the following result.

    $ psql -At -p 5433 -c "select nextval('seq')"
    5
    $ psql -At -p 5432 -c "select foreign_seq_nextval()"
    6
    $ psql -At -p 5433 -c "select nextval('seq')"
    7
    $ psql -At -p 5432 -c "select foreign_seq_nextval()"
    8

Creating an equivalent to nextval for global sequences (something like foreign\_nextval('seqname')) is quite simple with for example plpgsql and is let as an exercise for the reader.

As a conclusion, you can create tables using unique values across multiple nodes by associating for example foreign\_seq\_nextval() with DEFAULT for a column.

    =# CREATE TABLE tab (a int DEFAULT foreign_seq_nextval());
    CREATE TABLE
    =# INSERT INTO tab VALUES (DEFAULT), (DEFAULT), (DEFAULT);
    INSERT 0 3
    =# SELECT * FROM tab;
     a
    ----
     9
    10
    11
    (3 rows)

Et voila.
