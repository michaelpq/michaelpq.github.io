---
author: Michael Paquier
lastmod: 2011-12-02
date: 2011-12-02 04:34:31+00:00
layout: post
type: post
slug: setup-and-manipulation-of-a-postgres-xc-cluster-with-node-ddl
title: Setup and manipulation of a Postgres-XC cluster with node DDL
categories:
- PostgreSQL-2
tags:
- alter
- bash
- cluster
- connection
- create
- DDL
- drop
- global
- linux
- manipulation
- node
- pgxc
- pooler
- postgres
- postgres-xc
- postgresql
- remote
---

If you came at this page, it means that you got interest in a cluster solution based on PostgreSQL.
Currently developed for version 0.9.7, Postgres-XC has been largely improved with the way cluster is being set.

Just lately, I committed this commit.

    Support for dynamic pooler/session connection information cache reload

    A new system function called pgxc_pool_reload has been added.
    If called, this function reloads connection information to remote nodes
    in a consistent way with the following process:
    1) A lock is taken on pooler forbidding new connection requests
    2) Database pools (user and database-dependant pools) are reloaded
       depending on the node information located on catalog pgxc_node.
       The following rules are followed depending on node connection
       information modification:
       - node whose node and port value is changed has its connections
         dropped and this node pool is deleted from each database pool
       - node deleted is deleted from each database pool
       - node unchanged is kept as is. However, its index value is changed
         depending on the new cluster configuration.
       - node created is added to each database pool
    3) Lock is released
    4) Session that invocated pgxc_pool_reload signals all the other
       server sessions to reconnect to pooler to allow each agent to update
       with newest connection information and reload session information
       related to remote node handles. This has as effect to abort current
       transactions and to remove all the temporary and prepared objects
       on session. Then a WARNING message is sent back to client to inform
       about the cluster configuration modification.
    5) Session that invocated pgxc_pool_reload reconnects to pooler by
       itself and reloads its session information related to remote
       node handles. No WARNING message is sent back to client to inform
       about the session reload.
    This operation is limited to local Coordinator and returns a boolean
    depending on the success of the operation. If pooler data is consistent
    with catalog information when pgxc_pool_reload is invocated, nothing is
    done but a success message is returned.

    This has the following simplifications for cluster settings:
    - cluster_nodes.sql is deleted.
    - a new mandatory option --nodename is used to specify the node name
      of the node initialized. This allows to set up pgxc_node catalog
      with the node itself. pgxc_node_name in postgresql.conf is also
      set automatically.
    - CREATE/ALTER/DROP node are launched on local Coordinator only, meaning
      that when a cluster is set up, it is necessary to create node information
      on each Coordinator and then upload this information to pooler and sessions
      by invocaing pgxc_pool_reload.

    This optimization avoids to have to restart a Coordinator when changing
    cluster configuration and solves security problems related to cluster_nodes.sql
    that could be edited with all types of SQL even if its first target was only NODE
    DDL.

So what is behing this looooong commit text? Well, it is a feature that will simplify your life.
It is strongly related the feature called Node DDL. Just to recall, node DDL is a feature allowing to manage the cluster nodes with catalog tables such as you don't have to bother about heavy settings in postgresql.conf. However, even if node DDL have been supported, it does not mean that dropping, creating or altering a node is visible to the connection pooling. You had to restart a node, increasing by that much the downtime of each Coordinators.

This commit, in one word, introduces this => pgxc\_pool\_reload. It is a new system function used to check whose details are described here used to reload all the server sessions and pooler connection information without having to restart a Coordinator. In other words, it simplifies the way to set up a cluster.

Now let's enter in the main subject: the cluster setting, what can be done with the following steps:

  * Initialize the nodes with initdb
  * Create a global transaction manager and start it
  * Start up all the nodes
  * Connect to a Coordinator
  * Create all the nodes initialized with node DDL
  * Reload connection data with "select pgxc\_node\_reload();"

Here are a couple of details:

  * There is a new mandatory option in initdb called --nodename that is used to setup the name of the node being initialized. This is a Postgres-XC specific option. This option is used to define itself in pgxc\_node catalog the node being initialized. It also sets automatically pgxc\_node\_name in postgresql.conf.
  * You can check the consistency of the information cached in pooler and catalogs by calling the system function pgxc\_pool\_check. It returns a boolean on operation success or failure.
  * The specifications of node DDL is located at those pages: CREATE NODE, DROP NODE and ALTER NODE
  * Invocating pgxc\_pool\_reload aborts the current transaction, and drops all the prepared and temporary objects in session. This is effective in all the session of the server
  * Node DDL run locally, so you need to launch the same node DDL on all Coordinators of the cluster. This allows more smoothness in case Coordinators view the same Datanode with different IPs.

It is also possible to manipulate cluster nodes even after initialization. It doesn't matter how many times you change it as long as pgxc\_pool\_reload is used to update data cached in sessions and connection pool.

Here is also a bonus, a script that you can use to setup easily a cluster with a chosen number of Coordinators and Datanodes on a local machine. Port numbers are fixed, but it helps in trying Postgres-XC.

    #!/bin/bash
    #Otacoo.com

    #Build cluster from scratch and run pg_regress
    #1) Build the XC cluster: 1GTM with Coordinators (default 1) and Datanodes (default 2) defined 
    #2) Run pg_regress if wanted

    #Take and check options
    EXPECTED_ARGS=0
    FLAG_REGRESS=0
    NUM_COORDS=1
    NUM_DATANODES=2

    #Treat options
    while getopts 'c:n:r' OPTION
    do
        case $OPTION in
        c)  #Number of Coordinators
            NUM_COORDS="$OPTARG"
            EXPECTED_ARGS=$(($EXPECTED_ARGS + 2))
            ;;
        n)  #Number of Datanodes
            NUM_DATANODES="$OPTARG"
            EXPECTED_ARGS=$(($EXPECTED_ARGS + 2))
            ;;
        r)  #Run regressions or not?
            FLAG_REGRESS=1
            EXPECTED_ARGS=$(($EXPECTED_ARGS + 1))
            ;;
        ?)  echo "Usage: `basename $0` [-c num_coords] [-n num datanodes] [-r]\n"
            echo "Example: `basename $0` -c 4 -n 4 -r"
            exit 0
            ;;
        esac
    done

    #Check number of arguments
    if [ $# -ne $EXPECTED_ARGS ]
    then
        echo "Usage: `basename $0` [-c num_coords] [-n num datanodes] [-r]\n"
        echo "Example: `basename $0` -c 4 -n 4 -r"
        exit 1
    fi

    #Setup Default values
    #GTM has a unique value
    #Coordinator ports are mapped from 5432
    #Datanode ports are mapped from 15432
    #All the machines run on local host
    COORD_PORT_START=5431
    DN_PORT_START=15432
    COORD_PORTS[1]=$COORD_PORT_START
    DN_PORTS[1]=$DN_PORT_START
    for i in $(seq 1 $NUM_COORDS)
    do
        COORD_PORTS[$i]=$(($COORD_PORT_START + $i))
    done
    for i in $(seq 1 $NUM_DATANODES)
    do
        DN_PORTS[$i]=$(($DN_PORT_START + $i))
    done
    GTM_PORT=7777
    PSQL_FOLDER=$HOME/pgsql

    #Finish calculating dependencies between folders
    PSQL_SHARE=$PSQL_FOLDER/share
    PSQL_BIN=$PSQL_FOLDER/bin
    GTM_DATA=$PSQL_FOLDER/gtm
    LOG_DATA=$PSQL_FOLDER/log

    #Setup data folders
    for i in $(seq 1 $NUM_COORDS)
    do
        COORD_DATAS[$i]=$PSQL_FOLDER/coord$i
    done
    for i in $(seq 1 $NUM_DATANODES)
    do
        DN_DATAS[$i]=$PSQL_FOLDER/datanode$i
    done

    #Kill all the processes that may remain
    #in the most atrocious way possible as they meritated it
    #OK this is not very clean...
    echo "Take out Postgres-XC processes"
    kill -9 `ps ux | grep "bin/gtm" | cut -d " " -f 2-3`
    killall postgres gtm psql
    sleep 2

    #Check if data folders exist or not and create them
    echo "Creating data folders"
    for folder in $GTM_DATA $LOG_DATA ${COORD_DATAS[@]} ${DN_DATAS[@]}
    do
        if [ ! -d $CODE_REPO_GIT ]
        then
            mkdir $folder
        fi
    done

    #Clean up all the data folders
    echo "Clean up data folders"
    for folder in $GTM_DATA $LOG_DATA ${COORD_DATAS[@]} ${DN_DATAS[@]}
    do
        rm -r $folder/*
    done
    sleep 1

    #OK, let's begin the show...

    #make initialization
    echo "Initializing PGXC nodes"
    for i in $(seq 1 $NUM_DATANODES)
    do
        $PSQL_BIN/initdb --locale=POSIX --nodename dn$i -D ${DN_DATAS[$i]}
    done
    for i in $(seq 1 $NUM_COORDS)
    do
        $PSQL_BIN/initdb --locale=POSIX --nodename coord$i -D ${COORD_DATAS[$i]}
    done

    #copy all configuration files to remote machin
    echo "Copy of configuration files"
    #Create an empty GTM conf file and add host/port data
    touch $GTM_DATA/gtm.conf
    echo "nodename = 'one'" >> $GTM_DATA/gtm.conf
    echo "listen_addresses = '*'" >> $GTM_DATA/gtm.conf
    echo "port = 7777" >> $GTM_DATA/gtm.conf
    echo "log_file = 'gtm.log'" >> $GTM_DATA/gtm.conf

    #Node common settings
    OPTIONS="logging_collector = on\n"\
    "gtm_port = $GTM_PORT\n"\
    "datestyle = 'postgres, mdy'\n"\
    "timezone = 'PST8PDT'\n"\
    "default_text_search_config = 'pg_catalog.english'\n"\
    "log_statement = 'all'\n"\
    "log_min_messages = debug1\n"\
    "log_min_error_statement = debug1\n"\
    "max_prepared_transactions = 20\n"

    #Pooler options
    POOLER_BASE_PORT=6667
    #Coordinator settings
    for i in $(seq 1 $NUM_COORDS)
    do
        echo -e $OPTIONS >> ${COORD_DATAS[$i]}/postgresql.conf
        POOLER_NUM=$(($POOLER_BASE_PORT + $i))
        echo -e "pooler_port = $POOLER_NUM\n" >> ${COORD_DATAS[$i]}/postgresql.conf
    done
    #Datanode settings
    for i in $(seq 1 $NUM_DATANODES)
    do
        echo -e $OPTIONS >> ${DN_DATAS[$i]}/postgresql.conf
    done

    #launch gtm
    echo "launch GTM"
    $PSQL_BIN/gtm -x 10000 -D $GTM_DATA &
    sleep 1

    #launch datanodes
    echo "launch Datanodes..."
    for i in $(seq 1 $NUM_DATANODES)
    do
        $PSQL_BIN/postgres -X -i -p ${DN_PORTS[$i]} -D ${DN_DATAS[$i]} > $LOG_DATA/datanode$i.log &
    done
    sleep 1

    #launch coordinators
    echo "launching Coordinators..."
    for i in $(seq 1 $NUM_COORDS)
    do
        $PSQL_BIN/postgres -C -i -p ${COORD_PORTS[$i]} -D ${COORD_DATAS[$i]} > $LOG_DATA/coord$i.log &
    done
    sleep 1

    #Initialize Coordinators with cluster data
    echo "initializing Coordinators..."
    for i in $(seq 1 $NUM_COORDS)
    do
    #Datanode connection info
        for j in $(seq 1 $NUM_DATANODES)
        do
            NODE_NAME=dn$j
            NODE_PORT=${DN_PORTS[$j]}
            $PSQL_BIN/psql -p ${COORD_PORTS[$i]} -c "CREATE NODE $NODE_NAME WITH (HOSTIP = 'localhost', NODE MASTER, NODEPORT = $NODE_PORT);" postgres
        done
        #Other Coordinator info
        for j in $(seq 1 $NUM_COORDS)
        do
            if [ "$i" -eq "$j" ]
            then
                continue
            fi 
            NODE_NAME=coord$j
            NODE_PORT=${COORD_PORTS[$j]}
            $PSQL_BIN/psql -p ${COORD_PORTS[$i]} -c "CREATE NODE $NODE_NAME WITH (HOSTIP = 'localhost', COORDINATOR MASTER, NODEPORT = $NODE_PORT);" postgres
        done
        #reload data
        $PSQL_BIN/psql -p ${COORD_PORTS[$i]} -c "SELECT pgxc_pool_reload();" postgres
    done

    if [ "$FLAG_REGRESS" == 1 ]
    then
        echo "running pg_regress"
        pgregress
    fi

    exit `echo $?`
