---
author: Michael Paquier
lastmod: 2012-05-09
date: 2012-05-09 00:16:48+00:00
layout: post
type: post
slug: rules-in-postgres-xc
title: Rules in Postgres-XC
categories:
- PostgreSQL-2
tags:
- postgres
- postgres-xc
- postgresql
- rules
- cluster

---

One of the features that has been really improved the last couple of weeks is the stabilization of remote query planning for DML for Postgres-XC standard planner. And this has consequences on rules, because a rule is fired on Coordinators by design, and you need to provide a global way to plan queries correctly with remote nodes. Just to recall, a rule is the possibility to define an alternative action when doing an INSERT, UPDATE or DELETE on a table.
Another important point is that the query of a rules is not planned at the moment of the rule creation, but after rule is fired, however it doesn't change the fact that a correct query planning is needed at a moment or another.

A rule can for example be used to define DML on views.
A view is roughly a projection of table data into a wanted shape, and it is by default not possible to define DML actions on it.

Let's take an example, here are a simple table and a simple view.

    postgres=# CREATE TEMP TABLE t1 (a int PRIMARY KEY, b int) DISTRIBUTE BY HASH(a);
    NOTICE:  CREATE TABLE / PRIMARY KEY will create implicit index "t1_pkey" for table "t1"
    CREATE TABLE
    postgres=# INSERT INTO t1 VALUES (1,1),(2,2),(3,3),(4,4);
    INSERT 0 4
    postgres=# CREATE VIEW t1_v AS SELECT a AS a_v, b AS b_v FROM t1;
    NOTICE:  view "t1_v" will be a temporary view
    CREATE VIEW

When trying to UPDATE the view, you will get the following error.

    postgres=# UPDATE t1_v SET b_v = 2 WHERE a_v = 3;
    ERROR:  cannot update view "t1_v"
    HINT:  You need an unconditional ON UPDATE DO INSTEAD rule or an INSTEAD OF UPDATE trigger.

So let's define a view on it and check that an UPDATE on a view is possible.

    postgres=# CREATE RULE t1_upd AS ON UPDATE TO t1_v DO INSTEAD UPDATE t1 SET b = new.b_v WHERE a = old.a_v AND b = old.b_v;
    CREATE RULE
    postgres=# UPDATE t1_v SET b_v = 2 WHERE a_v = 3;
    UPDATE 1
    postgres=# select * from t1_v;
     a_v | b_v 
    -----+-----
       1 |   1
       2 |   2
       4 |   4
       3 |   2
    (4 rows)

So yes, RULES are now completely supported in Postgres-XC. And it is included in 1.0. The secret of how it works? The thing that took me 4 weeks to figure out?
Well, some extensions have been added in standard planner for DELETE, INSERT and UPDATE remote planning (ModifyTable used as TopPlan). For people willing to look at the code, all the secrets are located in functions create\_remoteinsert\_plan, create\_remoteupdate\_plan and create\_remotedelete\_plan of createplan.c. Those functions have been built and adapted to former scan plan of PostgreSQL to react as a wrapper for inner remote table scans within PostgreSQL standard planner. The trick is to create a DML query generated based on the scan plans generated for each tables that has to be updated, deleted or insert.

One of the limitations? The use of constraints.
Depending on the distribution strategy used, you may not be able to check the consistency of constraints globally.
But this is another story...
