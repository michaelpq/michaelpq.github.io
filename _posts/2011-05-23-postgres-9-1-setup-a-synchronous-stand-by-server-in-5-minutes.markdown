---
author: Michael Paquier
comments: true
lastmod: 2011-05-23
date: 2011-05-23 02:09:58+00:00
layout: post
type: post
slug: postgres-9-1-setup-a-synchronous-stand-by-server-in-5-minutes
title: 'Postgres 9.1: Setup a synchronous stand-by server in 5 minutes'
categories:
- PostgreSQL-2
tags:
- '9.1'
- beta
- easy
- handy
- hot standby
- postgres
- postgresql
- scripts
- server
- setup
- short
- standby
- streaming replication
- synchronous
---

PostgreSQL 9.1 is out, you can download it source code from [here](http://www.postgresql.org/ftp/source/) or use latest GIT repository as I did like this:

    mkdir postgres
    git remote add postgres http://git.postgresql.org/git/postgresql.git
    git fetch postgres
    git branch --track master postgres/master
    git checkout master

Asynchronous streaming replication is here since 9.0, but as I keep being always busy with development stuff of [Postgres-XC](http://postgres-xc.sourceforge.net/), I have not taken time to play around with streaming replication and HOT Standby.
As now synchronous streaming replication is going to be released soon (beta 1 at the moment of this post), and that Postgres-XC will soon be merged with PostgreSQL 9.1, I tried to set up a synchronous streaming replication server. This functionality could be used to extend XC so as to make it a full HA solution based on Postgres.

So, let's give it a try.

To be honest, I have been surprised by how easy it is to set it up. PostgreSQL developers have really done  a good job on it. As a beta 1, it is not completely polished, but it looks close to completion. Here are the main steps you need to do to set up your server.
First download code, and compile it (written above).

    ./configure --prefix=$HOME/bin/postgres
    make
    make install

In my case my installation is located at $HOME/bin/postgres, and I use the following folder for all my settings. You can of course use the folder you prefer, even for slave, master or archive data folders.

To understand what has to be set where, let's first have a look at the configuration parameters.
This is important to understand how to set your own servers, without depending on this post.
Settings are different for slave and master servers.

Here are the parameters you have to set for postgresql.conf file of master.

    wal_level = hot_standby
    archive_mode = on
    archive_command = 'cp -i %p $HOME/bin/postgres/archive/%f'
    max_wal_senders = 10

archive\_command is the command used when launching pg\_start\_backup. This allows slave to restore master data not from scratch, really accelerating slave's start up. In this case, directory for archives is $HOME/bin/postgres/archive.
max\_wal\_senders is the number of processes allowed to send WAL data, it cannot be 0, or master cannot send data to slave.
For the time being synchronous\_standby\_names is not set to avoid master hanging on a slave commit.
It is also necessary to set up your master to authorize connection from slave for replication purposes. In this case, you have to add those lines in pg\_hba.conf:

    host    replication     michael        127.0.0.1/32            trust
    host    replication     michael        ::1/128                 trust`

This setup is OK if slave and master are on local host.

In case you want to have a slave with the same configuration parameters as the master, you should copy copy the master's configuration file. Then modify the following parameters to make it a slave. In postgresql.conf:

    hot_standby = on
    port = 5433

It is also necessary to add an additional configuration file called recovery.conf in slave's data folder. You can find a sample of this file in share/ called recovery.conf.sample.
Rename it to recovery.conf and copy it to the slave's data folder. Then modify the following parameters in it.

    standby_mode = on
    primary_conninfo = 'host=localhost port=5432 application_name=slave1'
    restore_command = 'cp -i $HOME/bin/postgres/archive/%f %p'

primary\_conninfo contains all the connection parameters to allow slave to connect to master, for streaming replication purposes. In this parameter, application\_name is the name used to identify slave on master.
restore\_command contains a shell command that is used to copy archive files. This helps in speeding up slave startup by not having to copy all the WAL from scratch. In this case restore command picks up archive files in the same place where it has been saved by master.

Now, let's have a look at how to use your master/slave configuration.
Master port is 5432 (PostgreSQL default). Slave port is 5433.

This is the script I used to automatize the whole setup.

    #!/bin/bash  

    #Master has port 5432
    #Slave has port 5433
    PSQL_FOLDER=$HOME/bin/postgres
    PSQL_BIN=$PSQL_FOLDER/bin #Binary folder
    PSQL_CONFIG=$PSQL_FOLDER/config #Folder containing all the configuration files
    PSQL_MASTER=$PSQL_FOLDER/master #Master data folder
    PSQL_SLAVE=$PSQL_FOLDER/slave #Slave data folder
    PSQL_ARCHIVE=$PSQL_FOLDER/archive #Archive folder  

    #clean up, take down violently all the processes
    killall postgres
    rm -rf $PSQL_MASTER $PSQL_SLAVE $PSQL_ARCHIVE
    mkdir $PSQL_MASTER $PSQL_SLAVE $PSQL_ARCHIVE
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
    cp -pr $PSQL_MASTER/* $PSQL_SLAVE/
    $PSQL_BIN/psql postgres -c "select pg_stop_backup()"
    sleep 1
    echo "Backup performed"  

    #Setup synchronous commit mode on master
    echo "synchronous_standby_names='slave1'" >> $PSQL_MASTER/postgresql.conf
    $PSQL_BIN/pg_ctl reload -D $PSQL_MASTER
    echo "Force master to synchronize mode"
    sleep 1

    #Then finish by copying all the configuration files for slave
    cp -r $PSQL_MASTER/* $PSQL_SLAVE
    cp $PSQL_CONFIG/postgresql.conf.slave $PSQL_SLAVE/postgresql.conf
    cp $PSQL_CONFIG/recovery.conf.slave $PSQL_SLAVE/recovery.conf
    rm $PSQL_SLAVE/postmaster.pid
    rm -r $PSQL_SLAVE/pg_xlog/*  

    #Start Slave
    chmod 700 $PSQL_SLAVE
    $PSQL_BIN/postgres -D $PSQL_SLAVE &
    echo "Slave started"
    exit 0`

With this script, you can set up your own master/slave server based on streaming replication.

If you have finished wetting up your environment, let's check if it is working as planned. Slave can just perform read operations (no DML or DDL), and each write operation performed or master has to be seen on slave.
Let's first create a database.

    michael@lucid-virtual:~/bin/postgres $ ./bin/createdb test

Then create a table on master and fill it with some data.

    michael@lucid-virtual:~/bin/postgres $ ./bin/psql test
    psql (9.1beta1)
    Type "help" for help.
    test=# create table aa (a int);
    CREATE TABLE
    test=# insert into aa values (1);
    INSERT 0 1
    test=# select * from aa;
     a 
    ---
     1
    (1 row)`

And what happens on slave?

    michael@lucid-virtual:~/bin/postgres $ ./bin/psql -p 5433 test
    psql (9.1beta1)
    Type "help" for help.
    test=# select * from aa;
     a 
    ---
     1
    (1 row)
    test=# insert into aa values (2);
    ERROR:  cannot execute INSERT in a read-only transaction`

This works as expected (Oh, no configuration miss), slave has received all the data from master and cannot perform any write operations.

On master you can check if slave is synchronized with master correctly.

    test=# select application_name,state,sync_priority,sync_state from pg_stat_replication;
     application_name |   state   | sync_priority | sync_state 
    ------------------+-----------+---------------+------------
     slave1           | streaming |             1 | sync
    (1 row)`

The keyword sync means that master and slave have synchronized commits.
If it were not the case, this would be in async mode.

The main point of a slave is to take care of the database operations in case master crashes or becomes inoperative.
So let's imagine master crashes with something like.

    kill -9 `ps ux | grep "postgres/master" | cut -d " " -f 3`

Now only slave is running, but it cannot perform any write operation, so fallback can be done by:

    echo "standby_mode = off" >> slave/recovery.conf
    echo "port = 5432" >> slave/postgresql.conf
    ./bin/pg_ctl -D slave restart

Setting standby\_mode to off makes the slave react as a new master.
After restarting, recovery.conf has its name changed to recovery.done to prevent to reenter to a new backup.
After that a new master is up, based on the old slave. You can connect to it as if it was a normal master, and perform normal operations on it.
