---
author: Michael Paquier
lastmod: 2012-11-27
date: 2012-11-27 07:46:09+00:00
layout: post
type: post
slug: postgres-feature-highlight-pg_buffercache
title: 'Postgres feature highlight - pg_buffercache'
categories:
- PostgreSQL-2
tags:
- 9.2
- pg_buffercache
- postgres
- postgresql

---

[pg\_buffercache](http://www.postgresql.org/docs/current/static/pgbuffercache.html) is a PostgreSQL contrib module allowing to get an instant relation-based view of the shared buffer usage by querying the wanted server.

This can be pretty useful for performance analysis of queries on a given relation as it allows to have a look at how much a relation is cached. In the case of data cached for a given relation, you do not need to access data directly on disk to retrieve the data and can directly rely on the cache, so the data fetching is simply faster, by a factor of the order of 1000 (Shared memory/disk speed difference). Take care however that a shared lock is taken when analyzing the shared buffer content, so it can impact concurrent queries.

In order to install pg\_buffercache from source code, you need to perform the following commands to install its related files.

    cd contrib/pg_buffercache
    make install

Depending on your environment and the Postgres packages you installed, you might not need to do that of course. Once this is done the following files are installed in $INSTALL_FOLDER/share/extension.

    ls $INSTALL_FOLDER/share/extension
    pg_buffercache--1.0.sql
    pg_buffercache.control
    pg_buffercache--unpackaged--1.0.sql

Then connect to your Postgres server and finish pg_buffercache installation with CREATE EXTENSION command.

    postgres=# CREATE EXTENSION pg_buffercache;
    CREATE EXTENSION
    postgres=# \dx pg_buffercache
                        List of installed extensions
          Name      | Version | Schema |           Description           
    ----------------+---------+--------+---------------------------------
     pg_buffercache | 1.0     | public | examine the shared buffer cache
    (1 row)

The view created after installation of the extension called pg_buffercache has several columns.

  * bufferid, the block ID in the server buffer cache
  * relfilenode, which is the folder name where data is located for relation
  * reltablespace, Oid of the tablespace relation uses
  * reldatabase, Oid of database where location is located
  * relforknumber, fork number within the relation
  * relblocknumber, age number within the relation
  * isdirty, true if the page is dirty
  * usagecount, page LRU (least-recently used) count

The buffer ID corresponds (surprisingly!) to the number of the buffer used by the relation. The total number of buffers available is defined by two things:

  * Size of a buffer block, this is defined by the option --with-blocksize when running configure. Default value if 8kB, which is sufficient in most of the situations, but you can go up to 32kB or down to 1kB depending on the situations. In order to change this value, it is necessary to recompile the code and rebuild a database server from the initdb step.
  * Number of shared buffer allocated for the system defined by shared\_buffers in postgresql.conf. This can be changed at will by restarting the server.

For example, by using 128MB of shared\_buffers with 8kB of block size, there are 16,384 buffers, so pg\_buffercache has the same number of 16,384 rows.
With shared\_buffers set at 256MB and block-size at 1kB, there are 262,144 buffers.

Let's have a quick look at the feature with a pgbench database that has been already used with a 5-minute test. This simple query (given by the documentation) provides the number of buffers used by each relation of the current database.

    postgres=# SELECT c.relname, count(*) AS buffers
    postgres=# FROM pg_buffercache b INNER JOIN pg_class c
    postgres=# ON b.relfilenode = pg_relation_filenode(c.oid) AND
    postgres=# b.reldatabase IN (0, (SELECT oid FROM pg_database
    postgres=# WHERE datname = current_database()))
    postgres=# GROUP BY c.relname
    postgres=# ORDER BY 2 DESC
    postgres=# LIMIT 10;
            relname        | buffers 
    -----------------------+---------
     pgbench_history       |    2515
     pgbench_accounts      |    1818
     pgbench_accounts_pkey |     276
     pgbench_tellers       |      61
     pgbench_branches      |      61
     pg_attribute          |      22
     pg_statistic          |      11
     pg_proc               |      10
     pg_class              |       8
     pg_proc_oid_index     |       8
    (10 rows)

Not only relation data, but also indexes are included in the image given. The server of this example used an amount of shared_buffer of 128MB, so all the relation data was completely cached. The usage count of each buffer page is a good indication of how many times a buffer is used after being created. In case it is low, it means that the buffers do not survive a long time and that the cache hit ratio is low.
