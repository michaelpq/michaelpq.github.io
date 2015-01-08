---
author: Michael Paquier
lastmod: 2011-12-16
date: 2011-12-16 02:07:37+00:00
layout: post
type: post
slug: create-table-as-and-select-into-in-postgres-xc
title: CREATE TABLE AS and SELECT INTO in Postgres-XC
categories:
- PostgreSQL-2
tags:
- cluster
- create table as
- ctas
- data
- database
- distribution
- insert
- pgxc
- postgres
- query
- replication
- select
- select into
- sql
- support
- table
---

This week, a great feature has been added by commit [8a05756](http://postgres-xc.git.sourceforge.net/git/gitweb.cgi?p=postgres-xc/postgres-xc;a=commit;h=8a05756a702051d55a35ec3f4953f381f977b53a), completed by commit [caf1554](http://postgres-xc.git.sourceforge.net/git/gitweb.cgi?p=postgres-xc/postgres-xc;a=commit;h=caf15543cdadff39db3cae8e076b85d89ed6c8e6) in [Postgres-XC](http://postgres-xc.git.sourceforge.net/git/gitweb-index.cgi) GIT repository.

    commit 8a05756a702051d55a35ec3f4953f381f977b53a
    Author: Pavan Deolasee <pavan.deolasee@gmail.com>
    Date:   Wed Dec 14 09:35:53 2011 +0530

    Implement support for CREATE TABLE AS, SELECT INTO and INSERT INTO
    statements. We start by fixing the INSERT INTO support. For every result
    relation, we now build a corresponding RemoteQuery node so that the
    inserts can be carried out at the remote datanodes. Subsequently, at
    the coordinator at execution time, instead of inserting the resulting tuples
    in a local heap, we invoke remote execution and insert the rows in the
    remote datanodes. This works nicely even for prepared queries, multiple
    values clause for insert as well as any other mechanism of generating
    tuples.

    We use this infrastructure to then support CREATE TABLE AS SELECT (CTAS).
    The query is transformed into a CREATE TABLE statement followed by
    INSERT INTO statement and then run through normal planning/execution.

    There are many regression cases that need fixing because these statements
    now work correctly. This patch fixes many of them. Few might still be
    failing, but they seem unrelated to the work itself and might be a
    side-effect. We will fix them once this patch gets in.

Simply, this is the support for CREATE TABLE AS and SELECT INTO. All the possible combinations of INSERT SELECT are also possible whatever the type of table used.

Let's see through a couple of examples with this cluster of 1 Coordinator and 4 Datanodes.

    postgres=# select oid,node_name,node_type from pgxc_node;
      oid  | node_name | node_type 
    -------+-----------+-----------
     11133 | coord1    | C
     16384 | dn1       | D
     16385 | dn2       | D
     16386 | dn3       | D
     16387 | dn4       | D
    (5 rows)

Let's create a table and populate it with some data.

    postgres=# create table a as select generate_series(1,100);
    INSERT 0 100
    postgres=# select count(*) from a;
     count 
    -------
       100
    (1 row)

The data is distributed through the cluster of the 4 Datanodes.

    postgres=# execute direct on node dn4 'select count(*) from a';
     count 
    -------
        27
    (1 row)
    postgres=# execute direct on node dn3 'select count(*) from a';
     count 
    -------
        19
    (1 row)
    postgres=# execute direct on node dn2 'select count(*) from a';
     count 
    -------
        31
    (1 row)
    postgres=# execute direct on node dn1 'select count(*) from a';
     count 
    -------
        23
    (1 row)

CREATE TABLE AS is not only limited to global tables, you can define a distribution type, a subset of nodes, and of course the table can be unlogged or temporary. Here the table is distributed by round robin on datanodes dn1 and dn2.

    postgres=# create table c distribute by round robin to node dn1,dn2 as select * from b;
    INSERT 0 100
    postgres=# execute direct on node dn1 'select count(*) from c';
     count 
    -------
        50
    (1 row)
    postgres=# execute direct on node dn2 'select count(*) from c';
     count 
    -------
        50
    (1 row)
    postgres=# execute direct on node dn3 'select count(*) from c';
      count 
    -------
         0
    (1 row)
    postgres=# execute direct on node dn4 'select count(*) from c';
     count 
    -------
         0
    (1 row)

However, SELECT INTO does not have any extension for distribution type and node subsets. The reason for that is because SELECT INTO is by default a SELECT query, CREATE TABLE AS is a DDL. So in this case table created is distributed by hash on all the nodes.

    postgres=# select * into d from b;
    INSERT 0 100
    postgres=# select pclocatortype,nodeoids from pgxc_class where pcrelid = 'd'::regclass;
    -[ RECORD 1 ]-+------------------------
    pclocatortype | H
    nodeoids      | 16384 16385 16386 16387

Yeah, that rocks.
