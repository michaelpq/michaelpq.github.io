---
author: Michael Paquier
comments: true
date: 2011-08-15 06:56:58+00:00
layout: post
slug: postgresql-playing-with-foreign-data-wrappers-1
title: 'PostgreSQL: playing with foreign data wrappers (1)'
wordpress_id: 463
categories:
- PostgreSQL-2
tags:
- '8.4'
- '9.0'
- '9.1'
- '9.2'
- cvs
- fdw
- federated
- foreign data wrapper
- postgres
- postgresql
- server
---

This post presents some basics when using foreign data wrappers with PostgreSQL for external files.
FOREIGN DATA WRAPPER is a part of SQL/MED (Management of external data with SQL) and its implementation has begun since Postgres 8.4. This mechanism is based on COPY FROM to import data files directly into your database.
Those tests have been done with 9.2 (development version).

First be sure that the contrib module file_fdw is correctly installed for your server.

    cd /to/postgres/folder/contrib/file_fdw
    make install

At the time of this post, PostgreSQL tar just contains a fdw library for external files (file_fdw). Some complementary work for PostgreSQL fdw will be done as a development for 9.2.

If you do not install that, you may get the following error when trying to create an extension.

    CREATE EXTENSION file_fdw;
    ERROR:  could not open extension control file "/to/install/folder/share/extension/file_fdw.control": cannot find the following file

Let's then take a try.
First create a simple text file that will be converted. This file has a CVS format

    $ cat ~/data/test.data
    1,5,a
    2,4,b
    3,3,c
    4,2,d
    5,1,e

Then time to create the extension necessary for the fdw.

    template1=# CREATE EXTENSION file_fdw;
    CREATE EXTENSION

Then you need to create a *server* that will pinpoint to your file on your server.

    template1=# CREATE SERVER test_server FOREIGN DATA WRAPPER file_fdw;
    CREATE SERVER

As a last step, you only need to create a table referred in a foreign server 

    template1=# CREATE FOREIGN TABLE testdata (
    id1 int,
    id2 int,
    text1 char(1)
    ) SERVER test_server
    OPTIONS ( filename '/home/michael/data/test.data', format 'csv' );
    CREATE FOREIGN TABLE

Finally try to look at your data:

    template1=# select * from testdata;
     id1 | id2 | text1 
    -----+-----+-------
       1 |   5 | a
       2 |   4 | b
       3 |   3 | c
       4 |   2 | d
       5 |   1 | e
    (5 rows)

And you're done, congrats!
