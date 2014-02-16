---
author: Michael Paquier
comments: true
lastmod: 2011-06-22
date: 2011-06-22 00:55:25+00:00
layout: post
type: post
slug: synchronous-streaming-replicationstandby-nodes-in-a-cluster-for-an-ha-solution
title: Synchronous streaming replication/Standby nodes in a cluster for an HA solution
wordpress_id: 419
categories:
- PostgreSQL-2
tags:
- '9.0'
- '9.1'
- cluster
- database
- ha
- high-availability
- postgres
- postgres-xc
- postgresql
- scalability
- solution
- standby node
- streaming replication
---

The post presents a proposal to implement an HA solution based on PostgreSQL streaming replication and Standby node structure. This solution is still in construction, so the final implementation design that will be chosen for Postgres-XC may slightly change.

Before reading this post and if you are not experienced with PostgreSQL 9.0/9.1 features, you should refer to the [background about PostgreSQL Master/Slave fallback](http://michael.otacoo.com/postgresql-2/postgres-9-1-setup-a-synchronous-stand-by-server-in-5-minutes/).

### Synchronous streaming replication for Postgres-XC

This part specifies how synchronous streaming replication will be implemented in Postgres-XC. Even if functionalities in PostgreSQL 9.1 already implemented are pretty stable, some extensions related to node communication control have to be designed to have a real HA solution.

#### Some background

Postgres-XC is a multi-master database cluster based on PostgreSQL.

  * It is made of a unique global transaction manager which feeds consistently transaction IDs and snapshots in the cluster to each node.
  * Nodes are made of 2 kinds of nodes: Coordinator and Datanode.
    * Coordinators are holding other node information. A coordinator is able to communicate with other Coordinators and other Datanodes through a connection pooler. This connection pooler saves all the connection parameters to nodes (host name, port number) to be able to distribute connection with a libpq string protocol depending on database name and user name. Coordinators also have all the catalog information, and primarily the distribution information of each table in the database. With this information, Coordinator is able to push down SQL queries to correct Datanodes and then merge results that are sent back to application according a new plan type called RemoteQuery. A coordinator does not hold table data, and all the data contained each Coordinator is the same. So one Coordinator is the clone of another one.
    * Datanodes react more or less like a PostgreSQL normal instance. They hold database data. What has been added is an interface to permit Datanodes to receive from Coordinators transaction IDs, snapshots, timestamp values instead of requesting them locally.

#### Limitations

  * Postgres-XC does not support yet tuple relocation from one node to another (impossible to update for instance column that holds the distribution key), so this design is limited to the case where the cluster has a fixed number of master nodes (for Datanodes and Coordinators (?)).
  * It is not thought here about trying to add or delete a Datanode on the fly. By that, it means that cluster configuration is not changed in a way that it modifies the node number and data distribution.
  * With those assumptions what remains is a cluster with a fixed size
  * This specification is based on PostgreSQL 9.1, but design is though to take into account as many replication features as possible.

#### Specifications

Here are the list of functionalities that will be added for the support of synchronous streaming replication. Most of them concern node management, master/slave identification and slave promotion system.

  * In no way Postgres-XC nodes are thought as being able to make system calls to be able to kick a slave initdb or something like this. NO WAY!

##### Catalog addition

A catalog called pgxc\_nodes will be added with the following columns:

  * node type
  * node ID number
  * node host name
  * node port number
  * node immediate master ID
  * connection type: replication or not?

This table has as a primary key constraint on node number and node type.  

"node immediate master ID" is the node ID that a slave is using to connect to a master or another slave (case of cascade replication, not implemented in PostgreSQL 9.1 though). This catalog is created on Coordinator.

##### Cluster startup

  * As a limitation, all the configuration files of postgres-XC coordinator nodes only contain master Coordinator numbers.With that, the initialization of the catalog table pgxc\_nodes is made only with data of master nodes. In the case of a master node, "node immediate master ID" is filled with 0.
  * Once the cluster is up with a fixed number of nodes, the administrator has he possibility to update pgxc\_nodes catalog with slaves already on that have already there configuration files set correctly to connect to the wanted node.

##### SQL interface

###### Adding a slave node after cluster start up

Following SQL is sent to Coordinators:

    CREATE [COORDINATOR | DATANODE] SLAVE
    IDENTIFIED BY ID $id_num
    WITH CONNECTION ('$host1:$port1',...,'$hostN:$portN')
    ON MASTER $master_number.
    { REPLICATION TO [SYNCHRONOUS | ASYNCHRONOUS] }`


If only 1 host/port couple is specified, the same values are applied for all the coordinators. In case multiple host/port values are specified, they have to correspond to the number of Coordinators in the cluster. The following SQL is sent to all the coordinators. If replication option is not specified, slave is contacted to get the information.


###### Promoting a slave as a master

Following SQL is sent to Coordinators:

    ALTER [COORDINATOR | DATANODE] SLAVE id PROMOTE TO MASTER
    {WITH CONNECTION ( [:$port | $host: | $host:$port] )};

This will modify pgxc\_nodes like this for a coordinator for example:

  * Former tuples:
    * Master: C, ID: 1, host:localhost, port:5432, master ID: 0
    * Slave: C, ID: 4, host:localhost, port:5433, master ID: 1
  * New tuples:
    * Former master: erased
    * Slaved promoted: C, ID: 1, host:localhost, port:5432, master ID: 0

The following restrictions apply at promotion

  * Before promoting the slave as a new master it is necessary to restart slave new parameters. Postgres-XC does not take responsabilities in kicking new nodes.
  * Promotion can be made on a synchronous slave only, this check is made on pgxc\_nodes.
  * Before promoting, a check is made on slave to be sure that it has not been modified from synchronous to asynchronous mode when beginning the promotion. This check is done locally on pgxc\_nodes.
  * When promoting, make a check on slave node to be sure that its standby mode is off. This has to be kicked from an external utility and not by XC itself.

###### Changing a slave status

Following SQL is sent to Coordinators:

    ALTER [COORDINATOR | DATANODE] SLAVE $id REPLICATION TO [SYNCHRONOUS | ASYNCHRONOUS];
    ALTER [COORDINATOR | DATANODE] SLAVE $id ID TO $new_id;

The following rules are applied:

  * Take an exclusive lock on pgxc\_table to make other backends waiting on pgxc\_nodes
  * The lock is taken externally with LOCK TABLE and sent to all the Coordinators first. Then the table is updated. Then lock is released on all the Coordinators from remote Coordinator
  * When changing replication mode, connect to slave node and check if mode has effectively been changed correctly by an external application kick.

###### Disabling a slave node from cluster

Following SQL is Sent to Datanodes:

    DROP [COORDINATOR | DATANODE] SLAVE $id;

The following rules are applied:

  * Take an exclusive lock (SHARE ROW EXCLUSIVE MODE?) on pgxc\_nodes and send this lock to all the Coordinators before performing the deletion from pgxc\_nodes
  * Lock is released once deletion on all the nodes is completed

##### Pooler process modification

Connection pooling has to be modified with following guidelines:

  * At initialization phase, Pooler fills in the catalog table pgxc\_nodes with initial value in global memory context with values found in postgresql.conf: pgxc\_nodes has to be accessible from postmaster and child processes.
  * When a new slave is added with a new code ID, Pooler caches this new connection data on each Coordinator once pgxc\_nodes has been updated on Coordinator associated with new node ID.
  * When a slave is dropped, Pooler information cached is updated also.
  * Pooler saves in shared memory information related to master nodes at cluster initialization.

Important: Pooler only remains in charge in distributing connections. It does not have to know if connection is to a slave or a master. This is the reponsability of postgres child as it takes a row shared lock on pgxc\_nodes when beginning a transaction on certain nodes.

##### Postmaster child process modification

  * A child returns an error to application in case it cannot read pgxc\_nodes.
  * When a postmaster child determines the list of nodes for transaction, it needs to know if current transaction is read-only or write depending on SQL. Then node list is built from information in pgxc\_nodes when requesting new connections.
  * When a child postmaster uses connection information of a slave/master when taking new connections, it takes a row shared lock on the associated tuples of pgxc\_nodes where it took connections. This preserves catalog modification when running a transaction on those nodes.
    * If the transaction is read-only, connections to master/slave are both possible. Choice is made with round-robin.
    * If the transaction first requested read-only connections, but launches on the way a DML, new connections are requested from pooler to necessary masters.
    * If transaction was first write, then does read operations, keep going with connections to master.
