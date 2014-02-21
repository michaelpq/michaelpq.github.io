---
author: Michael Paquier
comments: true
lastmod: 2013-11-07
date: 2013-11-07 07:54:18+00:00
layout: post
type: post
slug: measuring-cascading-replication-lag-in-postgres
title: 'Measuring cascading replication lag in Postgres'
categories:
- PostgreSQL-2
tags:
- 9.2
- cascading
- database
- fast
- file
- lag
- master
- measure
- postgres
- postgresql
- replication
- root
- server
- slave
- slow
- time
---
Based on the scripts developped in a [previous post](http://michael.otacoo.com/postgresql-2/cascading-replication-in-chain-with-10-100-200-nodes/) where a couple of hundred of Postgres servers were linked with replication cascading, let's now have a look at the lag that cascading nodes have when creating several database objects.

The method used in this post to evaluate the lag is pretty simple, and is centralized on the use of pg\_stat\_file (thanks Jean-Guillaume from [Dalibo](http://www.dalibo.com/) for this tip), which allows to get information of a file in the data folder of the Postgres server. The idea here is simply to create an object (database or table), and then to scan in the data folder when a file related to this object has been created by the server. In order to do that, there are first two things to know:

  * A database use a folder located in base/$DBOID to store its data, DBOID being the OID of the database, findable in the catalog pg\_database.
  * A relation is stored on disk in a file called base/$DBOID/$RELFILE, DBOID being the database where the relation is located, and RELFILE the relation file node (relfilenode) of the... Relation. This information can be found in pg\_class with the relation OID as well.

So, knowing that 120 nodes have been created on a local VM, what would be the replication lag when creating a single database?

    =# CREATE DATABASE foo;
    CREATE DATABASE
    =# SELECT oid FROM pg_database WHERE datname = 'foo';
      oid
    -------
     16387
    (1 row)
    =# SELECT access FROM pg_stat_file('base/16387');
             access
    ------------------------
     2013-11-08 08:19:02+09
    (1 row)

And on the last node when is this database replicated?

    $ psql -p 5552 postgres -c "SELECT access FROM pg_stat_file('base/16387')"
              access
    ------------------------
     2013-11-08 08:19:09+09
    (1 row)

So the result is an honorable 7s of lag across 120 cascading nodes. Note that this lag was pretty stable even after multiple tries: 7s, 9s, 7s, 5s.

Creating a database is a costly operation, so what happens in the case of a table? Maybe it is faster?

    =# SELECT oid FROM pg_class where relname = 'bb';
      oid
    -------
     16393
    (1 row)
    =# SELECT oid FROM pg_database WHERE datname = 'postgres';
      oid
    -------
     12036
    (1 row)
    =# SELECT access FROM pg_stat_file('base/12036/16393');
             access
    ------------------------
     2013-11-08 08:23:51+09
    (1 row)

And on the last node?

    $ psql -p 5552 postgres -c "SELECT access FROM pg_stat_file('base/12036/16393')"
              access
    ------------------------
     2013-11-08 08:23:52+09
    (1 row)

So this time the lag for a table creation was 1s across 120 cascading nodes. This lag time remained constant after multiple tests run, reaching even less than 1s sometimes.

The test case of this post is really simple, so feel free to do similar tests with even larger chains of cascading nodes, or even on Postgres nodes running on different servers or VMs.
