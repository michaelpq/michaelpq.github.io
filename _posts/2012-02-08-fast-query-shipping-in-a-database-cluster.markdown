---
author: Michael Paquier
comments: true
lastmod: 2012-02-08
date: 2012-02-08 02:05:55+00:00
layout: post
type: post
slug: fast-query-shipping-in-a-database-cluster
title: Fast query shipping in a database cluster
categories:
- PostgreSQL-2
tags:
- cluster
- database
- expression
- fast
- pgxc
- planner
- postgres-xc
- postgresql
- pushdown
- query
- select
- shipping
- sql
- volatile
---

When using a database cluster where nodes are completely dependent on the network behavior like it is the case for shared-nothing based architecture, an essential step in integrating a new application is its design to maximize the performance and enhance the cluster strengths knowing its capabilities. The problem with shared-nothing architectures is that queries that may run very quickly in a single instance environment might take a bunch of time in your cluster, especially for queries having aggregates that need global results for all the nodes in the cluster or queries needing subsequent results from internal sub-queries. The nightmare of most of database developers trying to optimize an application is always to face queries of the type "SELECT *", fetching all the tuples of a table in a single shot. Such queries are already costly for single database instances, but just don't imagine how much you might load your application when fetching all the tuples of your table with additional node layers forcing your database to fetch results from multiple nodes.
I would say by experience that there are three guidelines when customizing an application for a cluster:

  * Choose the number of nodes in cluster and servers where they are located to minimize overall network load.
  * Customize queries such as they request results from a minimal number of nodes.
  * Design the data distribution strategy of your tables to minimize the results to be fetched to a single place for join conditions.

After this short digression, the aim of this post is not to discuss deeply about such conditions, it is to enlighten a feature that your application needs to target when you design its database. Well, the name of this feature is in the title, called "Fast Query Shipping". It is not really a feature in itself, more a goal applications should try to reach as much as possible to improve their performance on database cluster softwares. Fast query shipping (FQS) is the ability for a cluster to evaluate if a query can be completely shipped to a remote node in the cluster, making it a simple send and receive, minimizing the plan cost on the node planning the query and the data transfer cost because the data fetched from remote node with such a query is minimized to exactly what the application targets.

To be honest, googling "Fast Query shipping" does not bring any result except on Postgres-XC. The basic implementation of this feature has been done with the following commit.

    commit 191d55ebf1faf897aed51f1b5fdcd71ec3ccdc6c
    Author: Ashutosh Bapat <ashutosh.bapat@enterprisedb.com>
    Date:   Thu Feb 2 16:59:04 2012 +0530

    Add the support for Fast Query Shipping (FQS), a method to identify
    whether a query can be sent to the datanode/s as it is for evaluation and do so
    if deemed fit. In such cases, we create a plan with a single RemoteQuery node
    corresponding to the query and avoid the planning phase on coordinator.

    A query tree walker analyses all the nodes in the query tree and finds out the
    conditions under which the query is shippable and detects presence of
    expressions which can not be evaluated on the datanode. It looks at the
    relations involved in the query and deducts whether JOINs between these
    relations can be evaluated on a single datanode.

    Adds testcases xc_FQS and xc_FQS_join to test the fast query shipping
    functionality and make it independent of cluster configuration.

So, in this case, an extension of PostgreSQL planner has been done exclusively for Postgres-XC to evaluate if a query is entirely shippable to its dedicated remote node. This planning step determines the list of target nodes where to launch the query. The query can be basically shipped as depending on a lot of conditions like analysis of clauses, but basically you cannot ship a query if it contains expressions that cannot be evaluated on a remote node. A simple expression following that is the next value of a sequence, or timestamps. In a more general way it is a volatile or stable functions. There are also other expressions that cannot be shipped like window functions, GROUP BY clauses, aggregates, etc. Sometimes you may be able to ship entirely a query having an aggregate function, but targeting a single query. Well, there are a lot of cases possible, and you might look at the code in details if you are interested about each corner case.

Let's have a look at some simple test cases with replicated and hash tables:

    postgres=# create table rep (a int) distribute by replication;
    CREATE TABLE
    postgres=# create table hash (a int) distribute by hash(a);
    CREATE TABLE

For a table replicated on all nodes, shipping results from a single node is sufficient for the simple "select *". For a distribute table, all the nodes are targetted and results are sent back as such. This is in such configuration that you will get the most efficient queries running in a cluster environment.

    postgres=# explain select * from rep;
                                     QUERY PLAN                                 
    ----------------------------------------------------------------------------
      Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
        Node/s: dn1
    (2 rows)
    postgres=# explain select * from hash;
                                     QUERY PLAN                                 
    ----------------------------------------------------------------------------
     Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
       Node/s: dn1, dn2
    (2 rows)

A session parameter called enable_fast_query_shipping is available to set switch this feature to on/off. Let's see what happens.

    postgres=# SET enable_fast_query_shipping TO false;
    SET
    postgres=# explain select * from hash;
                                QUERY PLAN                             
    -------------------------------------------------------------------
     Result  (cost=0.00..1.01 rows=1000 width=4)
       ->  Data Node Scan on hash  (cost=0.00..1.01 rows=1000 width=4)
             Node/s: dn1, dn2
    (3 rows)
    postgres=# explain select * from rep;
                                QUERY PLAN                            
    ------------------------------------------------------------------
     Result  (cost=0.00..1.01 rows=1000 width=4)
       ->  Data Node Scan on rep  (cost=0.00..1.01 rows=1000 width=4)
             Node/s: dn1
    (3 rows)

Here what happens is that the query is not using any FQS features, so what happens is that you do not directly fetch the results from the node, but you also materialize them on the Coordinator where query is launched before sending them back to client.

This was a small introduction of the fast query shipping feature, just do not forget to test it.
