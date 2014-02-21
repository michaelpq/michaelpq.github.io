---
author: Michael Paquier
comments: true
lastmod: 2011-11-07
date: 2011-11-07 05:12:59+00:00
layout: post
type: post
slug: cascading-replication-in-postgresql
title: Cascading replication in PostgreSQL
categories:
- PostgreSQL-2
tags:
- '9.2'
- asynchronous
- cascade
- cascading replication
- database
- development
- ha
- high-availability
- master
- postgres
- postgresql
- replication
- slave
- streaming
---

It is planned in PostgreSQL 9.2 to have support for cascading replication, which is the ability to add slaves under other slaves. In 9.2, slave-slave connections are only asynchronous.

This feature has been introduced by this commit.

    commit 5286105800c7d5902f98f32e11b209c471c0c69c
    Author: Simon Riggs <simon@2ndQuadrant.com>
    Date:   Tue Jul 19 03:40:03 2011 +0100

    Cascading replication feature for streaming log-based replication.
    Standby servers can now have WALSender processes, which can work with
    either WALReceiver or archive_commands to pass data. Fully updated
    docs, including new conceptual terms of sending server, upstream and
    downstream servers. WALSenders terminated when promote to master.

    Fujii Masao, review, rework and doc rewrite by Simon Riggs`

So let's try to use it with a simple configuration of one master and four slaves. Two additional slaves are connected as well to the first slave.

Data files of master, slaves and archive folder are located in $HOME/bin/postgres.
You need to checkout the master branch of PostgreSQL GIT to try this feature.

The settings are pretty similar to what you can find [here](http://michael.otacoo.com/postgresql-2/postgres-9-1-setup-a-synchronous-stand-by-server-in-5-minutes/).
However, you have to take care of the following settings in postgresql.conf:

  * Master

    wal_level = hot_standby
    archive_mode = on
    archive_command = 'cp -i %p $HOME/bin/postgres/archive/%f'
    max_wal_senders = 10

  * Slave 1

    hot_standby = on
    port = 15432

  * Slave 2

    hot_standby = on
    port = 15433

  * Slave 1-1

    hot_standby = on
    port = 25432

  * Slave 1-2

    hot_standby = on
    port = 25433

You can setup slave1, and slave2 as synchronously with master by using synchronous\_standby\_names in postgresql.conf of master.
This is set a little bit later after initializing the master backup.

You need to change recovery.conf of slave 1 and slave 2 with those parameters:

    standby_mode = on
    primary_conninfo = 'host=localhost port=5432 application_name=$SLAVE_NAME'
    restore_command = 'cp -i $HOME/bin/postgres/archive/%f %p'

$SLAVE\_NAME being slave1 for slave 1, and slave2 for slave 2.

Then as, slave 1-1 and 1-2 have to connect to slave 1, use the same values as above for standby\_mode and restore\_command, but setup primary\_conninfo like this:

    primary_conninfo = 'host=localhost port=15432 application_name=$SLAVE_NAME'
    $SLAVE_NAME being slave11 for slave 1-1, and slave12 for slave 1-2.

Here is the dirty script used to start up the system. This has been written quickly, so sorry for the bad quality :).

    #!/bin/bash
    #Master has port 5432
    #Slave1 has port 15432
    #Slave2 has port 15433
    #Slave1 has port 25432
    #Slave2 has port 25433

    PSQL_FOLDER=$HOME/bin/postgres
    PSQL_BIN=$PSQL_FOLDER/bin #Binary folder
    PSQL_CONFIG=$PSQL_FOLDER/config #Folder containing all the configuration files
    PSQL_MASTER=$PSQL_FOLDER/master #Master data folder

    PSQL_SLAVE1=$PSQL_FOLDER/slave1 #Slave 1 data folder
    PSQL_SLAVE2=$PSQL_FOLDER/slave2 #Slave 2 data folder
    PSQL_SLAVE11=$PSQL_FOLDER/slave11 #Slave 11 data folder
    PSQL_SLAVE12=$PSQL_FOLDER/slave12 #Slave 12 data folder
    PSQL_ARCHIVE=$PSQL_FOLDER/archive #Archive folder

    #clean up, take down violently all the processes
    killall postgres
    rm -rf $PSQL_MASTER $PSQL_SLAVE1 $PSQL_SLAVE2 $PSQL_SLAVE11 $PSQL_SLAVE12 $PSQL_ARCHIVE
    mkdir $PSQL_MASTER $PSQL_SLAVE1 $PSQL_SLAVE2 $PSQL_SLAVE11 $PSQL_SLAVE12 $PSQL_ARCHIVE
    sleep 1

    #Initialize master
    $PSQL_BIN/initdb -D $PSQL_MASTER
    cp $PSQL_CONFIG/postgresql.conf.master $PSQL_MASTER/postgresql.conf
    cp $PSQL_CONFIG/pg_hba.conf.master $PSQL_MASTER/pg_hba.conf

    #Start master
    $PSQL_BIN/postgres -D $PSQL_MASTER &
    #Wait a little before server start up, let it finish initialization
    echo "Master started"
    sleep 2

    #Initialize slave
    #This is used to start the backup so as slave does not have to recover from
    #scratch when being build. It definitely accelerates standby start up
    $PSQL_BIN/psql postgres -c "select pg_start_backup('backup')"
    cp -pr $PSQL_MASTER/* $PSQL_SLAVE1/
    cp -pr $PSQL_MASTER/* $PSQL_SLAVE2/
    cp -pr $PSQL_MASTER/* $PSQL_SLAVE11/
    cp -pr $PSQL_MASTER/* $PSQL_SLAVE12/
    $PSQL_BIN/psql postgres -c "select pg_stop_backup()"
    echo "Backup performed"
    sleep 1

    #Setup synchronous commit mode on master
    echo "synchronous_standby_names='slave1,slave2'" >> $PSQL_MASTER/postgresql.conf
    $PSQL_BIN/pg_ctl reload -D $PSQL_MASTER
    echo "Force master to synchronize mode with slave1 (priority 1) and slave 2 (priority 2)"
    sleep 1

    #Then finish by copying all the configuration files for slaves
    cp $PSQL_CONFIG/postgresql.conf.slave1 $PSQL_SLAVE1/postgresql.conf
    cp $PSQL_CONFIG/recovery.conf.slave1 $PSQL_SLAVE1/recovery.conf
    cp $PSQL_CONFIG/postgresql.conf.slave2 $PSQL_SLAVE2/postgresql.conf
    cp $PSQL_CONFIG/recovery.conf.slave2 $PSQL_SLAVE2/recovery.conf
    cp $PSQL_CONFIG/postgresql.conf.slave11 $PSQL_SLAVE11/postgresql.conf
    cp $PSQL_CONFIG/recovery.conf.slave11 $PSQL_SLAVE11/recovery.conf
    cp $PSQL_CONFIG/postgresql.conf.slave12 $PSQL_SLAVE12/postgresql.conf
    cp $PSQL_CONFIG/recovery.conf.slave12 $PSQL_SLAVE12/recovery.conf

    #Delete unnecessary xlog files and postmaster pid files
    rm $PSQL_SLAVE1/postmaster.pid
    rm -r $PSQL_SLAVE1/pg_xlog/*
    rm $PSQL_SLAVE2/postmaster.pid
    rm -r $PSQL_SLAVE2/pg_xlog/*
    rm $PSQL_SLAVE11/postmaster.pid
    rm -r $PSQL_SLAVE11/pg_xlog/*
    rm $PSQL_SLAVE12/postmaster.pid
    rm -r $PSQL_SLAVE12/pg_xlog/*

    #Start Slave 1
    chmod 700 $PSQL_SLAVE1
    $PSQL_BIN/postgres -D $PSQL_SLAVE1 &
    echo "Slave 1 started"

    #Start Slave 2
    chmod 700 $PSQL_SLAVE2
    $PSQL_BIN/postgres -D $PSQL_SLAVE2 &
    echo "Slave 2 started"

    #Start Slave 11
    chmod 700 $PSQL_SLAVE11
    $PSQL_BIN/postgres -D $PSQL_SLAVE11 &
    echo "Slave 11 started"

    #Start Slave 12
    chmod 700 $PSQL_SLAVE12
    $PSQL_BIN/postgres -D $PSQL_SLAVE12 &
    echo "Slave 12 started"

    exit 0

OK now let's check if it works well.

    $ psql postgres
    postgres=# select application_name,state,sync_priority,sync_state from pg_stat_replication;
     application_name |   state   | sync_priority | sync_state 
    ------------------+-----------+---------------+------------
     slave1           | streaming |             1 | sync
     slave2           | streaming |             2 | potential
    (2 rows)

On master, slave1 has priority 1 for synchronization (synchronous\_standby\_nodes has been set up 'slave1,slave2'). It looks to be correctly synchronized.

Then let's do the same check from slave1.

    $ psql -p 15432 postgres
    postgres=# select application_name,state,sync_priority,sync_state from pg_stat_replication;
     application_name |   state   | sync_priority | sync_state 
    ------------------+-----------+---------------+------------
     slave12          | streaming |             0 | async
     slave11          | streaming |             0 | async
    (2 rows)

slave11 and slave12 are correctly linked to slave1. Yippee.

Why not some additional check with some data...

    $ #Connection from master
    $ psql -p 5432 postgres
    postgres=# create table aa (a int);
    CREATE TABLE
    postgres=# insert into aa values (1),(2);
    INSERT 0 2
    postgres=# select * from aa;
     a 
    ---
     1
     2
    (2 rows)
    postgres=# \q

Has the slave of a slave been updated? Connection to let's say... slave12

    $ psql -p 25433 postgres
    postgres=# select * from aa;
     a 
    ---
     1
     2
    (2 rows)

OK, that rocks. I let you imagine then how to use that as an HA solution ;).
