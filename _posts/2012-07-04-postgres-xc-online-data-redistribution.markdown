---
author: Michael Paquier
lastmod: 2012-07-04
date: 2012-07-04 05:56:51+00:00
layout: post
type: post
slug: postgres-xc-online-data-redistribution
title: 'Postgres-XC - online data redistribution'
categories:
- PostgreSQL-2
tags:
- distribution
- postgres
- postgres-xc
- postgresql
- sharding

---

Postgres-XC, as a sharding cluster (write-scalable, multi-master based on PostgreSQL) has currently a huge limitation related to the way tables are distributed.
Just to recall, tables can be either replicated, distributed by round robin, hash or modulo. For hash and modulo the distribution can be done based on the values of one column. Distribution type is defined thanks to an extension of CREATE TABLE.

    CREATE TABLE...
    [ DISTRIBUTE BY { REPLICATION | ROUND ROBIN | { [HASH | MODULO ] ( column_name ) } } ]
    [ TO ( GROUP groupname | NODE nodename [, ... ] ) ]

However once defined it cannot be changed while a cluster is running. There is still the method consisting in using a CREATE TABLE AS consisting in fetching all the data of the table into an intermediate one, then dropping the old table and remaming the intermediate table as the old one. This is enough for 1.0 but the table Oid is definitely lost.

One of the features I have been working these days is to provide to the applications a simple SQL interface that would allow to change a table distribution on the fly, meaning that all the data is transferred automatically between nodes with a single SQL.
This feature uses an extension to ALTER TABLE as follows:

    ALTER TABLE
    DISTRIBUTE BY { REPLICATION | ROUND ROBIN | { [HASH | MODULO ] ( column_name ) } }
    TO { GROUP groupname | NODE ( nodename [, ... ] ) }
    ADD NODE ( nodename [, ... ] )
    DELETE NODE ( nodename [, ... ] )

This basically means that you can change the distribution type of a table and the subset of nodes where data is located. The node list where data is distributed can be reset, increased or reduced at will.

The redistribution funcionality is still pretty basic, but what is simply does is:
	
  1. fetch all the data of the table to be redistributed on Coordinator	
  2. Truncate the table
  3. Update the catalogs to the new distribution type
  4. Redistribute the data cached on Coordinator

A tuple store is used to cache the data on Coordinator at phase 1, which can be customized with work\_mem. A COPY protocol is used to exchange the data between nodes as fastly as possible. This functionality also includes some new stuff to materialize in a tuple slot the data received with COPY protocol (reverse operation also implemented), essential when a tuple has to be redirected to a given node based on a hash value. And it looks that such a materialization mechanism would be a milestone to a more complex mechanism for global constraints and triggers in XC.
This is still a basic implementation, and the following improvements are planned once the basic stuff is committed:

  * Save materialization if it is not necessary (new distribution set to round robin, replication)	
  * Truncate the table on a portion of nodes if a replicated table has its subset of nodes reduced
  * COPY only necessary data for a replicated table to new nodes if its subset of nodes is increased
  * And a couple of other things

So how does it work? Let's take an example with this simple cluster, 1 Coordinator and 3 Datanodes:

    postgres=# select node_name, node_type from pgxc_node;
     node_name | node_type 
    -----------+-----------
     coord1    | C
     dn1       | D
     dn2       | D
     dn3       | D
    (4 rows)

A table aa is created as replicated with 10,000 rows on all the nodes.

    postgres=# CREATE TABLE aa (a int);
    CREATE TABLE
    postgres=# INSERT INTO aa VALUES (generate_series(1,10000));
    INSERT 0 10000
    postgres=# EXECUTE DIRECT ON (dn1) 'SELECT count(*) FROM aa';
     count 
    -------
     10000
    (1 row)
    postgres=# EXECUTE DIRECT ON (dn2) 'SELECT count(*) FROM aa';
     count 
    -------
     10000
    (1 row)
    postgres=# EXECUTE DIRECT ON (dn3) 'SELECT count(*) FROM aa';
     count 
    -------
     10000
    (1 row)

So here there are 10,000 tuples on each nodes, nothing fancy for a replicated table.

Let's change it to a hash-based distribution...

    postgres=# ALTER TABLE aa DISTRIBUTE BY HASH(a);
    NOTICE:  Copying data for relation "public.aa"
    NOTICE:  Truncating data for relation "public.aa"
    NOTICE:  Redistributing data for relation "public.aa"
    ALTER TABLE
    postgres=# EXECUTE DIRECT ON (dn1) 'SELECT count(*) FROM aa';
     count 
    -------
      3235
    (1 row)
    postgres=# EXECUTE DIRECT ON (dn2) 'SELECT count(*) FROM aa';
     count 
    -------
      3375
    (1 row)
    postgres=# EXECUTE DIRECT ON (dn3) 'SELECT count(*) FROM aa';
     count 
    -------
      3390
    (1 row)

Now one third of the data is on each node.

What happens if the set of nodes is reduced? Let's now remove the data on node dn2.

    postgres=# ALTER TABLE aa DELETE NODE (dn2);
    NOTICE:  Copying data for relation "public.aa"
    NOTICE:  Truncating data for relation "public.aa"
    NOTICE:  Redistributing data for relation "public.aa"
    ALTER TABLE
    postgres=# EXECUTE DIRECT ON (dn1) 'SELECT count(*) FROM aa';
     count 
    -------
      5039
    (1 row)
    postgres=# EXECUTE DIRECT ON (dn2) 'SELECT count(*) FROM aa';
     count 
    -------
         0
    (1 row)
    postgres=# EXECUTE DIRECT ON (dn3) 'SELECT count(*) FROM aa';
     count 
    -------
      4961
    (1 row)

The data is now hashed on nodes dn1 and dn3. There is no more data on dn2.

This implementation is still pretty basic, but opens a couple of possibilities for clustering applications, no?
