---
author: Michael Paquier
comments: true
date: 2012-11-28 03:54:09+00:00
layout: post
slug: postgres-fdw-highlight-redis_fdw
title: 'Postgres FDW highlight: redis_fdw'
wordpress_id: 1464
categories:
- PostgreSQL-2
tags:
- '9.1'
- '9.2'
- data
- fdw
- foreign
- key
- med
- mysql
- nosql
- open source
- oracle
- postgres
- postgresql
- query
- redis
- server
- sql
- value
- wrapper
---

A foreign-data wrapper (FWD) in a Postgres server allows to fetch data from an foreign entity or a foreign server. In this case, the Postgres planner and executer have the notion of what is called a foreign scan, which can be called using customized routines and fetch data that is not directly stored inside the Postgres server itself.

The core code of Postgres includes one FDW which is fdw_file, postgres_fdw is planned to be also included at some point (9.3 discussions).

The installation of a FDW can be done since PostgreSQL 9.1 with the use of CREATE EXTENSION. There are many existing FDW modules that are developed and maintained by the community. Among some of them are:
	
  * [oracle_fdw](http://oracle-fdw.projects.pgfoundry.org/), to fetch data from an Oracle server	
  * [mysql_fdw](https://github.com/dpage/mysql_fdw), to fetch data from a MySQL server
  * [pgsql_fdw](http://interdbconnect.sourceforge.net/pgsql_fdw/pgsql_fdw-ja.html) (or sometimes postgres_fdw), to fetch data from another Postgres server
  * [twitter_fdw](https://github.com/umitanuki/twitter_fdw), to fetch data from a Twitter server

Note: Once I thought about a git FDW as git is itself a NoSQL database managing concurrency of commits and branches its own way... But got no time to design or code it.

By the way, the FDW this post is focused on is called [redis_fdw](https://github.com/dpage/redis_fdw), which allows to fetch data from a foreign Redis server and materialize it directly on Postgres side. Before continuing reading this post, be sure that you already have running a [Redis server](http://michael.otacoo.com/redis/redis-first-steps-fetch-install-and-server-creation/) and a Postgres server.
Here both Redis and Postgres server run on a local machine with respectively 6379 and 5432 as port numbers (default values).

Then it is time to install redis_fdw. First fetch the code.

    mkdir $REDIS_SRC
    cd $REDIS_SRC
    git init
    git remote add origin https://github.com/dpage/redis_fdw.git
    git fetch origin
    git checkout master

Then install it. Please note that the current version of the code is not compilable with Postgres 9.2 and upper versions, so for this post the Postgres server is 9.1.X.
`make install USE_PGXS=1`
This will add redis_fdw.so in folder lib of pgsql install folder and redis_fdw.control and redis_fdw--1.0.sql in share/extension.
Then finalize installation on the server by using CREATE EXTENSION.

    postgres=# CREATE EXTENSION redis_fdw;
    CREATE EXTENSION
    postgres=# \dx redis_fdw
                              List of installed extensions
       Name    | Version | Schema |                   Description                    
    -----------+---------+--------+--------------------------------------------------
     redis_fdw | 1.0     | public | Foreign data wrapper for querying a Redis server
    (1 row)

Then create the foreign server, its attached foreign table and a user mapping for remote connectivity (you can also refer to the redis_fdw README for additional details).

    postgres=# CREATE SERVER redis_server
    postgres-# FOREIGN DATA WRAPPER redis_fdw
    postgres-# OPTIONS (address '127.0.0.1', port '6379');
    CREATE SERVER
    postgres=# 
    postgres=# CREATE FOREIGN TABLE redis_db0 (key text, value text)
    postgres-# SERVER redis_server
    postgres-# OPTIONS (database '0');
    CREATE FOREIGN TABLE
    postgres=# CREATE USER MAPPING FOR PUBLIC
    postgres-#         SERVER redis_server
    postgres-#         OPTIONS (password '');
    CREATE USER MAPPING

On the Redis server side, let's add a couple of keys with some values.

    # redis-cli
    redis 127.0.0.1:6379> set foo bar
    OK
    redis 127.0.0.1:6379> set foo2 bar2
    OK

Finally it is possible to query the Redis data directly by connecting on Postgres.

    postgres=# EXPLAIN VERBOSE SELECT * FROM redis_db0 WHERE key = 'foo2' OR key = 'foo';
                                     QUERY PLAN                                  
    -----------------------------------------------------------------------------
     Foreign Scan on public.redis_db0  (cost=10.00..12.00 rows=2 width=64)
       Output: key, value
        Filter: ((redis_db0.key = 'foo2'::text) OR (redis_db0.key = 'foo'::text))
        Foreign Redis Database Size: 2
    (4 rows)
    postgres=# SELECT * FROM redis_db0 WHERE key = 'foo2' OR key = 'foo';
     key  | value 
    ------+-------
     foo  | bar
     foo2 | bar2
    (2 rows)

And the set of key/values defined on Redis side have been fetched correctly.

Please note that redis_fdw code should not yet be used for production environment, I found for example that it crashes when the EXPLAIN query above is launched two times in a row. However, I think it is a good entry point to understand the possible Redis/Postgres interactions. It would also be worth stabilizing it and realigning it with Postgres master core code at some point.
