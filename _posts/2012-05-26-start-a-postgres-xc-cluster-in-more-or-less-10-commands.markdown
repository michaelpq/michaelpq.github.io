---
author: Michael Paquier
lastmod: 2012-05-26
date: 2012-05-26 02:32:14+00:00
layout: post
type: post
slug: start-a-postgres-xc-cluster-in-more-or-less-10-commands
title: Start a Postgres-XC cluster in (more or less) 10 commands
categories:
- PostgreSQL-2
tags:
- cluster
- command
- configurable
- database
- easy
- few
- install
- pgxc
- postgres
- postgres-xc
- postgresql
- short
---

First you need to download the latest version of Postgres-XC from [here](https://sourceforge.net/projects/postgres-xc/files/latest/download).

Then open the tarball and install the binaries as you would do with a normal PostgresSQL.

    configure --prefix=$INSTALL_FOLDER
    make
    make install

$INSTALL\_FOLDER is the folder where to install the sources. In this post $PATH redirects to $INSTALL\_FOLDER so no need to specify a folder when launching commands.

Next, the goal is to install a cluster when few simple commands.
Assuming that you are familiar with Postgres-XC architecture, this cluster is made with 1 Coordinator (to which your application connects), 2 Datanodes (meaning that your table data can be distributed up to 2 nodes) and a GTM, mandatory unique component distributing transaction ID and snapshot in the cluster.
If you are not familiar with the architecture, you can still refer to documents located [here](https://sourceforge.net/projects/postgres-xc/files/Presentation/). Among the documents available, the [tutorial done at PGCon 2012](https://sourceforge.net/projects/postgres-xc/files/Presentation/20120516_PGConTutorial/20120515_PGXC_Tutorial_global.pdf/download) is a good beginning.
For simplicity's sake, all the nodes are installed on a local machine.

Like PostgreSQL, each node of Postgres-XC needs a data folder. All of them are located in $DATA\_FOLDER.
So let's move in and initialize each node.

    cd $HOME/pgsql
    initgtm -Z gtm -D gtm # Initialize GTM
    initdb -D datanode1 --nodename dn1 # Initialize Datanode 1
    initdb -D datanode2 --nodename dn2 # Initialize Datanode 2
    initdb -D coord1 --nodename co1 # Initialize Coordinator 1

Then you need to modify manually the port value of Datanode 1 and Datanode 2 in each postgresql.conf.

    cd datanode1 # or `cd datanode2`
    vim postgresql.conf

Then change the line "#port = 5432" by "port = 15432" for Datanode 1, and "port = 15433" for Datanode 2.

Then it is time to start up the cluster.

    gtm -D gtm & # Start-up GTM
    postgres -X -D datanode1 -i & # Start Datanode 1
    postgres -X -D datanode2 -i & # Start Datanode 2
    postgres -C -D coord1 -i & # Start Coordinator 1

What remains is to set up the Coordinator to make him know about Datanode 1 and 2.
So connect to coordinator 1.

    psql postgres

Then launch that to finish setting up cluster:

    CREATE NODE dn1 WITH (TYPE='datanode', PORT=15432);
    CREATE NODE dn2 WITH (TYPE='datanode', PORT=15433);
    select pgxc_pool_reload();

And you are done.
Now you can connect to Coordinator 1 and test your newly-made cluster.
12 short commands have been enough once binaries have been installed.
