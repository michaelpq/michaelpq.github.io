---
author: Michael Paquier
comments: true
date: 2011-10-27 05:15:48+00:00
layout: post
slug: cluster-node-ddl-support-in-postgres-xc
title: Cluster node DDL support in Postgres-XC
wordpress_id: 591
categories:
- PostgreSQL-2
tags:
- cluster
- DDL
- information
- node
- port
- postgres
- postgres-xc
- postgresql
- preferred
- primary
---

After long weeks of battle, this week this commit has happened in [Postgres-XC's GIT repository](https://github.com/postgres-xc/postgres-xc).

    commit 56a90674444df1464c8e7012c6113efd7f9bc7db
    Author: Michael P <michaelpq@users.sourceforge.net>
    Date:   Thu Oct 27 10:57:30 2011 +0900

    Support for Node and Node Group DDL

    Node information is not anymore supported by node number using
    GUC parameters but node names.
    Node connection information is taken from a new catalog table
    called pgxc_node. Node group information can be found in pgxc_group.

    Node connection information is taken from catalog when user session
    begins and sticks with it for the duration of the session. This brings
    more flexibility to the cluster settings. Cluster node information can
    now be set when node is initialized with initdb using cluster_nodes.sql
    located in share directory.

This commits adds support for the following new DDL:

  * CREATE NODE
  * ALTER NODE
  * DROP NODE
  * CREATE NODE GROUP
  * DROP NODE GROUP

The following parameters are deleted from postgresql.conf:

  * num_data_nodes
  * preferred_data_nodes
  * data_node_hosts
  * data_node_ports
  * primary_data_node
  * num_coordinators
  * coordinator_hosts
  * coordinator_ports

pgxc_node_id is replaced by pgxc_node_name to identify the node-self.

Documentation is added for the new queries. Functionalities such as
EXECUTE DIRECT, CLEAN CONNECTION use node names instead of node numbers now.

So what is it about? Until now Postgres-XC has only used a heavy configuration to set up node connection information. There were 8 parameters dedicated to Coordinators and Datanodes, and those parameters had to follow a special format.
Now, the following SQL queries can be issued to set up cluster connection information, and information is cached once user session is up.
For the time being, a file called cluster_nodes.sql has to be set in share folder for initdb. But soon functionalities will be added to update pooler connection information based on node information update, insert or deletion.
This brings a lot of simplicity in cluster setting. And now, nodes are not identified by their position number in a GUC string, but by a unique global name that maintains consistency in the whole cluster.

Here are some examples of cluster settings.
1 Coordinator and 2 Datanodes:

    CREATE NODE coord1 WITH (HOSTIP = 'localhost', COORDINATOR MASTER, NODEPORT = $COORD1_PORT);
    CREATE NODE dn1 WITH (HOSTIP = 'localhost', NODE MASTER, NODEPORT = $DN1_PORT, PREFERRED);
    CREATE NODE dn2 WITH (HOSTIP = 'localhost', NODE MASTER, NODEPORT = $DN2_PORT, PRIMARY);

2 Coordinators and 2 Datanodes:

    CREATE NODE coord2 WITH (HOSTIP = 'localhost', COORDINATOR MASTER, NODEPORT = $COORD2_PORT);
    CREATE NODE coord1 WITH (HOSTIP = 'localhost', COORDINATOR MASTER, NODEPORT = $COORD1_PORT);
    CREATE NODE dn2 WITH (HOSTIP = 'localhost', NODE MASTER, NODEPORT = $DN2_PORT, PRIMARY);
    CREATE NODE dn1 WITH (HOSTIP = 'localhost', NODE MASTER, NODEPORT = $DN1_PORT, PREFERRED);

So, what happens in the cluster for 2 Datanodes and 2 Coordinators?

    postgres=# select oid,* from pgxc_node;
    -[ RECORD 1 ]----+----------
    oid              | 11133
    node_name        | coord1
    node_type        | C
    node_related     | 0
    node_port        | 5432
    node_host        | localhost
    nodeis_primary   | f
    nodeis_preferred | f
    -[ RECORD 2 ]----+----------
    oid              | 11134
    node_name        | coord2
    node_type        | C
    node_related     | 0
    node_port        | 5452
    node_host        | localhost
    nodeis_primary   | f
    nodeis_preferred | f
    -[ RECORD 3 ]----+----------
    oid              | 11135
    node_name        | dn1
    node_type        | D
    node_related     | 0
    node_port        | 15451
    node_host        | localhost
    nodeis_primary   | f
    nodeis_preferred | t
    -[ RECORD 4 ]----+----------
    oid              | 11136
    node_name        | dn2
    node_type        | D
    node_related     | 0
    node_port        | 15452
    node_host        | localhost
    nodeis_primary   | t
    nodeis_preferred | f

Other functionalities now also work with node names, like EXECUTE DIRECT and CLEAN CONNECTION:

    postgres=# clean connection to node dn1 for database postgres;
    CLEAN CONNECTION
    postgres=# execute direct on node dn1 'select oid,* from pgxc_node where node_type = ''D''';
    -[ RECORD 1 ]----+----------
    oid              | 11135
    node_name        | dn1
    node_type        | D
    node_related     | 0
    node_port        | 15451
    node_host        | localhost
    nodeis_primary   | f
    nodeis_preferred | t
    -[ RECORD 2 ]----+----------
    oid              | 11136
    node_name        | dn2
    node_type        | D
    node_related     | 0
    node_port        | 15452
    node_host        | localhost
    nodeis_primary   | t
    nodeis_preferred | f
