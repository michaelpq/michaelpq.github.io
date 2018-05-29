---
author: Michael Paquier
lastmod: 2013-02-22
date: 2013-02-22 01:47:46+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-postgres_fdw
title: 'Postgres 9.3 feature highlight - postgres_fdw'
categories:
- PostgreSQL-2
tags:
- 9.3
- fdw
- foreign
- postgres
- postgresql

---

Up to Postgres 9.2, the only foreign data wrapper present in core was file\_fdw, allowing you to query files as remote tables. This has been corrected with the addition of a second foreign data wrapper called postgres\_fdw. This one simply allows to query foreign Postgres servers and fetch results directly on your local server. It has been introduced by this commit.

    commit d0d75c402217421b691050857eb3d7af82d0c770
    Author: Tom Lane <tgl@sss.pgh.pa.us>
    Date:   Thu Feb 21 05:26:23 2013 -0500
    
    Add postgres_fdw contrib module.
    
    There's still a lot of room for improvement, but it basically works,
    and we need this to be present before we can do anything much with the
    writable-foreign-tables patch.  So let's commit it and get on with testing.
    
    Shigeru Hanada, reviewed by KaiGai Kohei and Tom Lane

Documentation can be found [here](https://www.postgresql.org/docs/devel/static/postgres-fdw.html) for the time being.

In order to install it from source, do the following commands from the Postgres root folder.

    cd contrib/postgres_fdw
    make install

Then connect to your existing Postgres server and finish the installation with CREATE EXTENSION.

    postgres=# CREATE EXTENSION postgres_fdw;
    CREATE EXTENSION
    postgres=# \dx postgres_fdw
                                 List of installed extensions
         Name     | Version | Schema |                    Description                     
    --------------+---------+--------+----------------------------------------------------
     postgres_fdw | 1.0     | public | foreign-data wrapper for remote PostgreSQL servers
    (1 row)

Now let's test it with the case of a simple cluster with one slave running with port 5532 on the same server as its master. Here is the configuration.

    $ psql -p 5532 -c 'select pg_is_in_recovery()'
     pg_is_in_recovery 
    -------------------
     t
    (1 row)

When using a foreign data wrapper, you need to create first a server.

    postgres=# CREATE SERVER postgres_server
    postgres=# FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host 'localhost', port '5532', dbname 'postgres');
    CREATE SERVER
    postgres=# \des
                 List of foreign servers
           Name       | Owner  | Foreign-data wrapper 
     -----------------+--------+----------------------
      postgres_server | xxxxxx | postgres_fdw
    (1 row)

Then let's move on with a user mapping and a table to query.

    postgres=# CREATE USER MAPPING FOR PUBLIC SERVER postgres_server OPTIONS (password '');
    CREATE USER MAPPING
    postgres=# CREATE TABLE aa AS SELECT 1 AS a, generate_series(1,3) AS b;
    CREATE TABLE

As the foreign server used is the slave of our master, there is no need to create this table on the second node.

What remains is the creation of the foreign table.

    postgres=# CREATE FOREIGN TABLE aa_foreign (a int, b int)
    postgres=# SERVER postgres_server OPTIONS (table_name 'aa');
    CREATE FOREIGN TABLE

Then if you query the foreign table.

    postgres=# select * from aa_foreign;
     a | b 
    ---+---
     1 | 1
     1 | 2
     1 | 3
    (3 rows)

Yeah, done!

This feature still needs more testing, so go ahead and test it by yourself you might be surprised with the things you can do with it.
