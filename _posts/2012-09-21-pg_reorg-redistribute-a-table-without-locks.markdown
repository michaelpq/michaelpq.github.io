---
author: Michael Paquier
comments: true
date: 2012-09-21 02:39:01+00:00
layout: post
slug: pg_reorg-redistribute-a-table-without-locks
title: pg_reorg, reorganize a table without locks
wordpress_id: 1315
categories:
- PostgreSQL-2
tags:
- contrib
- database
- flexible
- index
- log
- module
- ntt
- open source
- pg_reorg
- postgres
- postgresql
- reorganization
- table
- vacuum
---

pg_reorg is a postgresql module developped and maintained by NTT that allows to redistribute a table without taking locks on it.
The code is hosted by pg_foundry [here](http://pgfoundry.org/projects/reorg/).
However, pgfoundry uses CVS :(, so I am also maintaining a fork in github in sync with pgfoundry [here](https://github.com/michaelpq/pg_reorg).

What pg_reorg can do for you is to reorganize a whole table in the same fashion way as a CLUSTER or a VACUUM FULL, while allowing write operations on the table being reorganized at the same time. No locks are needed.

Once you have downloaded the code, you just need to install it on your server.

    cd $CODE_FOLDER
    make install

Then install the EXTENSION module (for version upper than 9.1) after connecting to the postgres server.

    CREATE EXTENSION pg_reorg;

Then, it is possible to perform several types of operations.
CLUSTER reorganization on the table $TABLE.

    pg_reorg --dbname $DATABASE -t $TABLE

VACUUM FULL reorganization on the table $TABLE.

    pg_reorg --dbname $DATABASE -t $TABLE -n

Reorganization of an entire database.

    pg_reorg --dbname $DATABASE

The main limitation of this utility is that table being redistributed needs to have a primary key or a non-null unique key.

Then, a little bit more about the technique it uses to reorganize the table.
Basically, a temporary copy of the table to be redistributed is created using a CREATE TABLE AS query. The CTAS query definition is changed depending on the distribution user wants. For example, if user wants a redistribution using a different column (option -o), the CTAS is completed with an ORDER BY clause on the wanted column. The indexes of the new table depend on what the user wants.

Then the following operations are done.

  * creation of triggers to register all the DMLs that occur on the former table to an intermediate log table
  * creation of indexes on the temporary table based on what the user wants (new column index, VACUUM FULL...)
  * Apply the logs registered during the index creation and wait for old transactions to finish
  * Swap the names between the freshly-created table and old table
  * Drop the useless objects: the old table, the old triggers and remaining objects

This functionality is particularly handy when you wish to reorganize a huge table. Performing a VACUUM/CLUSTER on it might take time, and your application might need this table to be accessible in write for a maximum amount of time. So pretty useful, uh?
