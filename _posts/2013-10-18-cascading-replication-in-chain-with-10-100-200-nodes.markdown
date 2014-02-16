---
author: Michael Paquier
comments: true
lastmod: 2013-10-18
date: 2013-10-18 08:29:49+00:00
layout: post
type: post
slug: cascading-replication-in-chain-with-10-100-200-nodes
title: 'Cascading replication in chain with 10, 100, 200 nodes?'
wordpress_id: 2006
categories:
- PostgreSQL-2
tags:
- 100
- 200
- 9.2
- 9.3
- api
- cascading
- chain
- database
- function
- hundred
- long
- node
- open source
- postgres
- release
- replication
- shell
---
[Cascading replication](http://michael.otacoo.com/postgresql-2/cascading-replication-in-postgresql/) has been introduced in 9.2, but have you ever tried long chains of cascading nodes in Postgres?

In the case of this post, I simply tried to run as many nodes as possible in a VM with 4GB of memory. Each node has the following set of parameters, the goal being to minimize the use of memory for each one.

    max_connections = 3
    superuser_reserved_connections = 0
    max_wal_senders = 2
    hot_standby = on
    wal_level = hot_standby
    archive_mode = on
    work_mem = 64kB
    shared_buffers = 128kB
    temp_buffers = 800kB
    maintenance_work_mem = 1MB
    max_stack_depth = 100kB

In this case at least 3 max\_connections have been necessary, max\_wal\_senders needing to have 2 slots for the replication and pg\_basebackup as each slave was taking a pg\_basebackup from the node it connects to. This could be done far better with a single base backup from the master though and max\_connections set at 2, I just wanted here to have the node creation method consistent for ALL the nodes. :)

Then, some explanations about how I did that with a script coded in 10 minutes... First here is the script:

    #!/bin/bash
    # Some initialization
    NUMBER_NODES=10
    BASE_PGDATA=~/desktop/cascade
    BASE_MASTER=$BASE_PGDATA/master
    MASTER_PORT=`postgres_get_port`

    # Create master -c cascade
    rm -rf $BASE_MASTER
    postgres_node_init -p $MASTER_PORT -d $BASE_MASTER -c cascade
    pg_ctl -D $BASE_MASTER start
    sleep 1
    createdb -p $MASTER_PORT $USER
    psql -d $USER -p $MASTER_PORT -c 'CREATE TABLE aa(a int)'
 
    # Initialize port slave node needs to connect to
    ROOT_PORT=$MASTER_PORT
    for count in `seq 1 $NUMBER_NODES`
    do
      SLAVE_PORT=`postgres_get_port`
      SLAVE_DATA=$BASE_PGDATA/slave_$SLAVE_PORT
      rm -rf $SLAVE_DATA
 
      # Create slave node
      postgres_node_init -d $SLAVE_DATA -p $SLAVE_PORT -q $ROOT_PORT -s \
        -c cascade
      pg_ctl -D $SLAVE_DATA start
      sleep 1
      psql -d $USER -p $MASTER_PORT -c "INSERT INTO aa VALUES ($count);"
      # Next slave will connect to this node
      ROOT_PORT=$SLAVE_PORT
    done

It does nothing extraordinary, simply initializing a master node, and then it creates a slave with a for loop, each slave connecting to the previous node created. Note that this script runs using two in-house scripts that I simply use for Postgres development: postgres\_init\_node, able to initialize a Postgres master or slave node, and postgres\_get\_port. Both things are available on github... postgres\_init\_node can take in argument the following things:

  * -d PATH for the data folder of the new node
  * -p PORT for the port of the new node
  * -s to define if the node is a standby or not
  * -q PORT to define the port where node needs to connect if it is a standby
  * -c SUFFIX is an internal mechanism used to enforce the node initialization to use a set of parameters for postgresql.conf, in this case the memory values minimized

This script remains simple, as it is assumed that all the nodes run locally, particularly useful for development purposes. The second script, called postgres\_get\_node, scans psql ports already in use and gets a new one. There is nothing complicated in, and it can be easily broken as well. But for development on a VM, this is more than enough when you need to deploy your tools quickly and efficiently... And in this case only a git clone is enough.

Using those things, how many nodes have run in chain? Here are the results of this experiment...
At 100 nodes, still fine...
At 128 nodes, system complained about the maximum number of semaphores reached... A quick look at the dedicated system file later...

    $ cat /proc/sys/kernel/sem
    250 32000 32 128

... And after updating it to far higher values, process just went up to 275 nodes in chain but stopped there as the VM was lacking in disk space (only 16G, memory was getting close to its limit btw). Still this number is already interesting knowing that everything ran a single VM.

Note that the cascading was working really smoothly even with this high number of nodes. I did not really have any motivation to check the replication delay, but by running commands like the one below I did not see any delays when checking on the last node of the chain the creation of the new table on the master node:

    psql -c 'create table ac (a int)'; psql -p $LAST_NODE_PORT -c '\d'
