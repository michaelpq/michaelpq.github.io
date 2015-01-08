---
author: Michael Paquier
lastmod: 2011-11-16
date: 2011-11-16 02:23:15+00:00
layout: post
type: post
slug: pgxc-data-distribution-in-a-subset-of-nodes
title: 'PGXC: data distribution in a subset of nodes'
categories:
- PostgreSQL-2
tags:
- cluster
- data
- database
- node
- pgxc
- portion
- postgres
- postgres-xc
- postgresql
- software
- subset
---

Just yesterday I committed that.

    commit 2aea0c2e0e01031f5dd4260b6985dc0ed4eadc50
    Author: Michael P <michaelpq@users.sourceforge.net>
    Date:   Tue Nov 15 09:54:54 2011 +0900

    Support for data distribution among a subset of datanodes

    CREATE TABLE has been extended with the following clause:
    CREATE TABLE ...
    [ TO ( GROUP groupname | NODE nodename [, ... ] ) ]

    This clause allows to distribute data among a subset of nodes
    listed by a node list, or a group alias.
    Node groups can be defined with CREATE NODE GROUP.

    The base structure for this support was added with commit
    56a90674444df1464c8e7012c6113efd7f9bc7db, but check of mapping of
    subsets of node list was still missing for the management of join
    push down and materialization evaluation in planner.

So what the hell is it??? Simply a feature that allows you to better control the data distributed among your Postgres-XC cluster.

Let's take an example of a cluster with 2 Coordinators and 4 Datanodes.

    postgres=# select oid,node_name from pgxc_node;
      oid  | node_name 
    -------+-----------
     11133 | coord1
     11134 | coord2
     11135 | dn1
     11136 | dn2
     11137 | dn3
     11138 | dn4
    (6 rows)

Prior to this functionality, creating a table forced you to distribute the data among all the datanodes of your cluster.

    postgres=# create table test (a int);
    CREATE TABLE
    postgres=# select nodeoids from pgxc_class where pcrelid = 'test'::regclass;
            nodeoids         
    -------------------------
     11135 11136 11137 11138
    (1 row)

Now, CREATE TABLE has a new clause extension to be able to create a table only on a subset of nodes.
This is documented here.
The new clause is written as:

    CREATE TABLE
    ...
    [ TO ( GROUP groupname | NODE nodename [, ... ] ) ]

So you can specify a list of node names or a node group. A node group is simply an alias for a node list.
Let's try it.

  * test12\_rep is a replicated table whose data is distributed in nodes 1 and 2
  * test34\_hash is a hash table whose data is distributed in nodes 3 and 4
  * test234\_rep is a replicated table whose data is distributed in nodes 2, 3 and 4

    postgres=# create table test12_rep (a int) distribute by replication to node dn1,dn2;
    CREATE TABLE
    postgres=# create table test34_hash (a int) distribute by hash(a) to node dn3,dn4;
    CREATE TABLE
    postgres=# create node group dn234 with dn2,dn3,dn4;
    CREATE NODE GROUP
    postgres=# create table test234_rep (a int) distribute by replication to group dn234;
    CREATE TABLE
    -- Check the node subset for distribution
    postgres=# select nodeoids from pgxc_class where pcrelid = 'test12_rep'::regclass;
      nodeoids   
    -------------
     11135 11136
    (1 row)
    postgres=# select nodeoids from pgxc_class where pcrelid = 'test34_hash'::regclass;
      nodeoids   
    -------------
     11137 11138
    (1 row)
    postgres=# select nodeoids from pgxc_class where pcrelid = 'test234_rep'::regclass;
         nodeoids      
    -------------------
     11136 11137 11138
    (1 row)

Now let's insert some data.

    postgres=# insert into test12_rep values (1),(2),(3);
    INSERT 0 3
    postgres=# insert into test234_rep values (1),(2),(3);
    INSERT 0 3
    postgres=# insert into test34_hash values (1),(2),(3);
    INSERT 0 3

Then is data of test12_rep correctly distributed?

    postgres=# execute direct on node dn1 'select * from test12_rep';
     a 
    ---
     1
     2
     3
    (3 rows)
    postgres=# execute direct on node dn2 'select * from test12_rep';
     a 
    ---
     1
     2
     3
    (3 rows)
    postgres=# execute direct on node dn3 'select * from test12_rep';
     a 
    ---
    (0 rows)
    postgres=# execute direct on node dn4 'select * from test12_rep';
     a 
    ---
    (0 rows)

test12\_rep is only replicated in nodes dn1 and dn2 only.

Let's do the same checks for test234\_rep and test34\_hash.

    --First for test34_hash
    postgres=# execute direct on node dn1 'select * from test34_hash';
     a 
    ---
    (0 rows)
    postgres=# execute direct on node dn2 'select * from test34_hash';
     a 
    ---
    (0 rows)
    postgres=# execute direct on node dn3 'select * from test34_hash';
     a 
    ---
     1
     2
    (2 rows)
    postgres=# execute direct on node dn4 'select * from test34_hash';
     a 
    ---
     3
    (1 row)
    --Then for test234_rep
    postgres=# execute direct on node dn1 'select * from test234_rep';
     a 
    ---
    (0 rows)
    postgres=# execute direct on node dn2 'select * from test234_rep';
     a 
    ---
     1
     2
     3
    (3 rows)
    postgres=# execute direct on node dn3 'select * from test234_rep';
     a 
    ---
     1
     2
     3
    (3 rows)
    postgres=# execute direct on node dn4 'select * from test234_rep';
     a 
    ---
     1
     2
     3
    (3 rows)

So test234\_rep is correctly replicated in nodes 2, 3 and 4. test34\_hash is correctly hash-partitioned in nodes 3 and 4.

Now let's do some join and push down checks.

    postgres=# explain verbose select a from test34_hash join test234_rep using (a);
                                QUERY PLAN                             
    -------------------------------------------------------------------
    Data Node Scan (Node Count [2])  (cost=0.00..0.00 rows=0 width=0)
    Output: test34_hash.a
    (2 rows)

In this case replicated table test234\_rep is completely mapped by test34_hash so a push down is possible to nodes 3 and 4 directly.

    postgres=# explain verbose select a from test34_hash join test12_rep using (a);
                                               QUERY PLAN                                            
    ------------------------------------------------------
    Nested Loop  (cost=0.00..2.04 rows=1 width=4)
    Output: test34_hash.a
    Join Filter: (test34_hash.a = test12_rep.a)
      ->  Materialize  (cost=0.00..1.01 rows=1 width=4)
      Output: test34_hash.a
        ->  Data Node Scan (Node Count [2]) on test34_hash  (cost=0.00..1.01 rows=1000 width=4)
        Output: test34_hash.a
        ->  Materialize  (cost=0.00..1.01 rows=1 width=4)
          Output: test12_rep.a
          ->  Data Node Scan (Node Count [1]) on test12_rep  (cost=0.00..1.01 rows=1000 width=4)
            Output: test12_rep.a
    (11 rows)

In this case test34\_hash and test12\_rep are distributed on a disjoined list of nodes, so performing a join needs to first fetch data from Datanodes then materialize it on Coordinator.

There is still no way to change the table distribution type or the node list after table creation. This is one of the next plans, based on ALTER TABLE this time.
