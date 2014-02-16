---
author: Michael Paquier
comments: true
lastmod: 2012-06-01
date: 2012-06-01 07:50:39+00:00
layout: post
type: post
slug: first-steps-with-dblink-on-postgres
title: First steps with dblink on Postgres
wordpress_id: 1023
categories:
- PostgreSQL-2
tags:
- cluster
- connection
- dblink
- initiation
- postgres
- postgresql
- remote
- server
- sql
- step
---

This short manual targets PostgreSQL users looking for a smooth introduction to dblink.

[dblink](http://www.postgresql.org/docs/9.1/static/dblink.html) is a PostgreSQL contrib module that can be found in the folder contrib/dblink. It is treated as an extension, meaning that the installation of this module is in two phases, explained in this post a bit later.
The goal of this module is to provide simple functionalities to connect and interact with remote database servers from a given PostgreSQL server to which your client application or driver is connected.

The first thing that you need to do is to install the sources of dblink. You can do it easily by installing all the modules of PostgreSQL at once from source code.

    ./configure --prefix $INSTALL_FOLDER
    make install-world

$INSTALL\_FOLDER is the folder where you wish to install PostgreSQL binaries.

Or if you wish only to install dblink (you might have already installed PostgreSQL ressources), do it directly from its source folder.

    cd contrib/dblink
    make install

The installed files for dblink can be found in $INSTALL\_FOLDER/share/extensions.

    $ cd $INSTALL_FOLDER/share/extension
    $ ls dblink*
    dblink--1.0.sql  dblink--unpackaged--1.0.sql  dblink.control

For the purpose of this demonstration, two PostgreSQL servers called server1 and server2 are created on the same local server with port values respectively of 5432 and 5433.

Some data will be inserted on server2, and the goal is to fetch this data to server1 using dblink.

Let's first prepare server 2 and create some data on it.

    $ psql -p 5433 postgres
    psql (9.2beta1)
    Type "help" for help.
    postgres=# create table tab (a int, b varchar(3));
    CREATE TABLE
    postgres=# insert into tab values (1, 'aaa'), (2,'bbb'), (3,'ccc');  
    INSERT 0 3

So now that the remote server2 is ready to work, all the remaining tasks need to be done on server1.

The sources of dblink have been installed, but they are not yet active on server1. dblink is treated as an extension, which is a functionality that has been introduced since PostgreSQL 9.1. In order to activate a new extension module, here dblink, on a PostgreSQL server, the following commands are necessary.

    $ psql postgres
    psql (9.2beta1)
    Type "help" for help.
    postgres=# CREATE EXTENSION dblink;
    CREATE EXTENSION
    postgres=# \dx
                                     List of installed extensions
      Name   | Version |   Schema   |                         Description                          
    ---------+---------+------------+--------------------------------------------------------------
     dblink  | 1.0     | public     | connect to other PostgreSQL databases from within a database
     plpgsql | 1.0     | pg_catalog | PL/pgSQL procedural language
    (2 rows)

You can then confirm that the extension has been activated by using \dx from a psql client.

Now let's fetch the data from server2 with dblink while connecting on server1. The function dblink can be invocated to fetch data as it uses as return type "SETOF record". This implies that the function has to be called in FROM clause.

    postgres=# select * from dblink('port=5433 dbname=postgres', 'select * from tab') as t1 (a int, b varchar(3));
     a |  b  
    ---+-----
     1 | aaa
     2 | bbb
     3 | ccc
    (3 rows)

Do not forget to use aliases in the FROM clause to avoid errors of the following type:

    postgres=# select * from dblink_exec('port=5433 dbname=postgres', 'select * from tab');
    ERROR:  statement returning results not allowed

It is also possible to do more fancy stuff with dblink functions.
dblink\_connect allows you to create a permanent connection to a remote server. Such connections are defined by names you can choose. This avoids to have to create new connections to remote servers all the time at invocating of function dblink, allowing to gain more time by maintaining connections alive. In case you wish to use the connection created, simply invocate its name when using dblink functions.

Execution of other queries, like DDL or DML, can be done with function dblink\_exec.

    postgres=# select dblink_exec('port=5433 dbname=postgres', 'create table aa (a int, b int)');
     dblink_exec  
    --------------
     CREATE TABLE
    (1 row)

dblink has a dozen of functions that allows to control remote database servers from a single connection point.
be sure to have a look at it!
