---
author: Michael Paquier
comments: true
date: 2013-07-09 03:00:27+00:00
layout: post
type: post
slug: first-steps-with-pgbouncer-how-to-set-and-run-it
title: 'First steps with pgbouncer, how to set and run it '
wordpress_id: 2015
categories:
- PostgreSQL-2
tags:
- compile
- connection
- database
- idle
- maximum
- open source
- pgbouncer
- pooling
- postgres
- postgresql
- query
- run
- session
- settings
- transaction
---

pgbouncer is a connection pooling utility that can be plugged on top of a PostgreSQL server. It can be used to limit the maximum number of connections on server side by managing a pool of idle connections that can be used by any applications. Something particularly good about pgbouncer is that it offers the same level of transparency as a normal PostgreSQL server when an application connects to it. Also, the project is mature for years, its code is stable and is used in many production environments.

Here are some steps to follow if you want to have a first experience with pgbouncer using raw code. First fetch the code from its git repository.

    git clone git://git.postgresql.org/git/pgbouncer.git pgbouncer

Be aware that pgbouncer has a dependency with libevent, and that it uses a git submodule (in this case particular initialization is required).

Compiling the code can be done as follows.

    cd $TO_GIT_REPO
    # --recursive is not mandatory here but if the structure of pgbouncer
    # is changed with multiple layers of submodules, so use that as generic command
    git submodule update --init --recursive
    # Generate configure
    ./autogen.sh
    ./configure prefix=$INSTALL_REPO
    make
    make install

Once done, the binary of pgbouncer will be available in $INSTALL\_REPO/bin. Some documentation and configuration file templates is installed in $INSTALL\_REPO/share/doc/pgbouncer.

The use of a configuration file is mandatory. If this file does not exist when launching the application, pgbouncer complains like that:

    $ pgbouncer 
    Need config file.  See pgbouncer -h for usage.

The most important configuration parameter to be aware of is the connection pooling strategy. This choice depends exclusively on the application you are going to use. There are three modes available:

  * session, the connection to server is kept as long as the client is connected to pgbouncer
  * transaction, the connection is kept only during the duration of a transaction. It is obtained when the transaction begins, and pulled back to the connection pool once transaction is over
  * statement, which is a pretty aggressive mode. The connection is put back to pull once query completes. Only autocommit transactions can use this mode, which can be useful for applications with short transactions, so forget about transactions having multiples queries in this mode

The second thing coming to my mind is that pgbouncer in session mode can make really easy the management of session-based objects within connections of the pool as this avoids having to reload the same objects on each connection to server all the time. For example you could design a single function defined on PostgreSQL server side in charge of loading a bunch of PREPARE statements for each new connection, designed to satisfy the needs of your application. Then clients would just need to use EXECUTE to run queries. By default, pgbouncer cleans up connections with DISCARD ALL, so be sure to change that also to your needs.

Perhaps, a last thing to remember: pgbouncer can do a little bit of load balancing. For example, for a given hostname if the DNS returns multiple IP addresses, those ones are used in round-robin manner. It is also possible to dedicate an IP address to a given database name. For example let's imagine the case of a cluster with one slave and one master, you could choose to have database1 connect only to the master, while database2 connects only to the slave.

By the way, here is a minimal configuration file you could use for a development environment for example.

    [databases]
    * = host=localhost port=5432 user=$USER
    
    [pgbouncer]
    listen_port = 5433
    listen_addr = localhost
    auth_type = any
    logfile = pgbouncer.log
    pidfile = pgbouncer.pid

auth\_type set to 'any' is extremely permissive, as all the users can log in as administrators. There are also [many more options available](http://pgbouncer.projects.pgfoundry.org/doc/config.html) to help customizing the level of security at the user and database level. In section "databases", be aware that it is necessary to specify a user name for the default database name, usually a user with low permission level, but in a development environent it doesn'T really matter...

Here is an example of section "databases" to redirect a given database to a slave (here on same host with port 5532).

    [databases]
    popo = host=localhost port=5432 dbname=popo user=$USERNAME
    popo2 = host=localhost port=5532 dbname=popo2 user=$USERNAME
    * = host=localhost port=5432 user=$USERNAME

In this case, a user connecting to all the databases except popo2 will be redirected to the master.

Once the configuration is done, it is time to start pgbouncer.

    $ pgbouncer config.ini 
    2013-07-09 11:38:11.955 10153 LOG File descriptor limit: 1024 (H:4096), max_client_conn: 100, max fds possible: 110
    2013-07-09 11:38:11.958 10153 LOG listening on ::1/5433
    2013-07-09 11:38:11.958 10153 LOG listening on 127.0.0.1:5433
    2013-07-09 11:38:11.958 10153 LOG listening on unix:/tmp/.s.PGSQL.5433
    2013-07-09 11:38:11.958 10153 LOG process up: pgbouncer 1.5.4, libevent 2.0.21-stable (epoll), adns: evdns2

So everything is running fine now. Congratulations.

And you can connect to it at will as a normal server.

    $ psql -p 5433 postgres
    psql (9.4devel)
    Type "help" for help.
    postgres=#

One last thing... There is a database dedicated to the administration tasks called pgbouncer. It offers also some additional features to control the different pools being run and to get statistics of the system. Be sure to have a look "SHOW HELP" to grab more information on that when connected to this particular database.
