--
author: Michael Paquier
comments: true
date: 2013-01-22 08:36:36+00:00
layout: post
slug: postgres-9-3-feature-highlight-copy-freeze
title: 'Postgres 9.3 feature highlight: COPY FREEZE'
wordpress_id: 1602
categories:
- PostgreSQL-2
tags:
- '9.3'
- commit
- copy
- data
- database
- feature
- freeze
- open source
- performance
- postgres
- postgresql
- release
- vacuum
---

Continuing with the new features planned for PostgreSQL 9.3, here are some explanations about a new COPY mode called FREEZE. This feature has been introduced by this commit.

    commit 8de72b66a2edcf12c812de0a73bd50b6b7d81d62
    Author: Simon Riggs <simon@2ndQuadrant.com>
    Date:   Sat Dec 1 12:54:20 2012 +0000

    COPY FREEZE and mark committed on fresh tables.
    When a relfilenode is created in this subtransaction or
    a committed child transaction and it cannot otherwise
    be seen by our own process, mark tuples committed ahead
    of transaction commit for all COPY commands in same
    transaction. If FREEZE specified on COPY
    and pre-conditions met then rows will also be frozen.
    Both options designed to avoid revisiting rows after commit,
    increasing performance of subsequent commands after
    data load and upgrade. pg_restore changes later.

    Simon Riggs, review comments from Heikki Linnakangas, Noah Misch and design
    input from Tom Lane, Robert Haas and Kevin Grittner

With an additional tweak for CREATE TABLE.

    commit 1f023f929702efc9fd4230267b0f0e8d72ba5067
    Author: Simon Riggs <simon@2ndQuadrant.com>
    Date:   Fri Dec 7 13:26:52 2012 +0000

    Optimize COPY FREEZE with CREATE TABLE also.

    Jeff Davis, additional test by me

This feature allows to insert rows already *frozen* during the COPY process, the same thing can be done with a VACUUM FREEZE after doing a normal COPY, but it is always nice to have the possibility to do that during the process, especially if a lot of data is loaded. Such *frozen* rows are already marked as committed at insert, which is good for performance but not that much for visibility, as the rows loaded are viewable from other sessions while being loaded. So this feature is limited to some particular conditions:

  * Table been freshly created or truncated in current subtransaction
  * No older snapshots
  * No open cursors

If one of those conditions is not satisfied, COPY will fail silently and return to a normal process.

Let's see how this works with a simple set of data like that.

    $ cat ~/desktop/data.txt 
    1,2
    3,4
    5,6
    7,8

In the case of a normal COPY, you would get something like that (replace $HOME by your own local folder).

    postgres=# CREATE TABLE aa (a int, b int);
    CREATE TABLE
    postgres=# COPY aa FROM '$HOME/desktop/data.txt' DELIMITER ',';
    COPY 4
    postgres=# SELECT xmin,xmax,a,b FROM aa WHERE a = 1;
     xmin | xmax | a | b 
    ------+------+---+---
      687 |    0 | 1 | 2
    (1 row)

Have a look at the xmin value, it has been set to the XID of the transaction used.

A COPY FREEZE needs to be done on a fresh table, so you can use it like this.

    postgres=# BEGIN;
    BEGIN
    postgres=# CREATE TABLE aa (a int, b int);
    CREATE TABLE
    postgres=# COPY aa FROM '$HOME/desktop/data.txt' DELIMITER ',' FREEZE;
    COPY 4
    postgres=# COMMIT;
    COMMIT
    postgres=# SELECT xmin,xmax,a,b FROM aa WHERE a = 1;
     xmin | xmax | a | b 
    ------+------+---+---
        2 |    0 | 1 | 2
    (1 row)

xmin has been aggressively set to 2.

Note that this also works with TRUNCATE.
    postgres=# BEGIN;
    BEGIN
    postgres=# TRUNCATE aa;
    TRUNCATE TABLE
    postgres=# COPY aa FROM '$HOME/desktop/data.txt' DELIMITER ',' FREEZE;
    COPY 4
    postgres=# COMMIT;
    COMMIT
    postgres=# SELECT xmin,xmax,a,b FROM aa WHERE a = 1;
     xmin | xmax | a | b 
    ------+------+---+---
        2 |    0 | 1 | 2
    (1 row)

Let's see if the conditions to perform the FREEZE are not met:

    postgres=# TRUNCATE aa;
    TRUNCATE TABLE
    postgres=# BEGIN;
    BEGIN
    postgres=# COPY aa FROM '$HOME/desktop/data.txt' DELIMITER ',' FREEZE;
    COPY 4
    postgres=# COMMIT;
    COMMIT
    postgres=# SELECT xmin,xmax,a,b FROM aa WHERE a = 1;
     xmin | xmax | a | b 
    ------+------+---+---
      692 |    0 | 1 | 2
    (1 row)

Note once again that xmin is set normally.

And it looks to be all for this new feature, have fun with it.
