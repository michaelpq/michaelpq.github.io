---
author: Michael Paquier
comments: true
lastmod: 2011-12-12
date: 2011-12-12 05:53:56+00:00
layout: post
type: post
slug: postgres-xc-node-ddl-grammar-fixed
title: 'Postgres-XC: Node DDL grammar fixed'
categories:
- PostgreSQL-2
tags:
- cluster
- coordinator
- database
- datanode
- DDL
- fix
- grammar
- node
- pgxc
- postgres-xc
- query
- server
---

With last week's [commit](http://postgres-xc.git.sourceforge.net/git/gitweb.cgi?p=postgres-xc/postgres-xc;a=commitdiff;h=2a406e56dea3e750e74cc38115e83e30217b4822;hp=99407dfd856b4250593379a6764f9bbd61ae03f7):

    commit 2a406e56dea3e750e74cc38115e83e30217b4822
    Author: Michael P <michaelpq@users.sourceforge.net>
    Date:   Thu Dec 8 13:50:25 2011 +0900

    Simplify node DDL grammar and supress slave management part

    New grammar uses WITH clause of CREATE TABLE in this manner:
    CREATE/ALTER NODE nodename WITH (
    [ TYPE = ('coordinator' | 'datanode'),]
    [ HOST = 'string',]
    [ PORT = portnum,]
    [ PRIMARY,]
    [ PREFERRED ]);
    This applies to CREATE/ALTER NODE.
    Grammar simplification results in the deletion in related_to column
    of pgxc_node catalog.

    Documentation is updated in consequence.

    This commit solves also an issue with variable names sharing same
    format between GTM and XC nodes.

The grammar of node DDL (CREATE NODE, ALTER NODE, DROP NODE) has been simplified and made more consistent with PostgreSQL. Now those queries are adapted as follows:

  * Use of the same WITH clause as CREATE TABLE
  * No slave nodes taken into account anymore: now a slave node needs to have the same name as its master. This facilitates also failover.

In consequence, here is how to create a cluster with a freshly-started Coordinator called coord1 and 2 Datanodes called dn1 and dn2 using respectively ports 15433 and 15434.

    postgres=# create node dn1 with (type = 'datanode', port = 15433, host = 'localhost');
    CREATE NODE
    postgres=# create node dn2 with (type = 'datanode', port = 15434, host = 'localhost');
    CREATE NODE
    postgres=# select pgxc_pool_reload();
     pgxc_pool_reload 
    ------------------
     t
    (1 row)
    postgres=# select pgxc_pool_check();
     pgxc_pool_check 
    -----------------
     t
    (1 row)
    postgres=# select * from pgxc_node;
     node_name | node_type | node_port | node_host | nodeis_primary | nodeis_preferred 
    -----------+-----------+-----------+-----------+----------------+------------------
     coord1    | C         |      5432 | localhost | f              | f
     dn1       | D         |     15433 | localhost | f              | f
     dn2       | D         |     15434 | localhost | f              | f
    (3 rows)

In bonus to this article, you can find [here](/wp-content/uploads/2011/12/start_cluster_2.tar.gz) an updated version of the script that can setup a cluster on a local machine with the following options:

  * -c to indicate the number of Coordinators
  * -n to indicate the number of Datanodes
