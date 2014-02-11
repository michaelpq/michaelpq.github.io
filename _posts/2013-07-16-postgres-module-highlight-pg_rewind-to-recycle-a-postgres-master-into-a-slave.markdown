---
author: Michael Paquier
comments: true
date: 2013-07-16 07:33:42+00:00
layout: post
slug: postgres-module-highlight-pg_rewind-to-recycle-a-postgres-master-into-a-slave
title: 'Postgres module highlight: pg_rewind, to quickly recycle a Postgres master
  into a slave'
wordpress_id: 2067
categories:
- PostgreSQL-2
tags:
- '9.3'
- analyze
- block
- cluster
- database
- master
- module
- open source
- pg_rewind
- postgres
- quick
- recycle
- repurpose
- rewind
- slave
- speed
---

Managing wisely server resources has always been a critical matter for all kinds of systems. A lack of resource would mean a loss of performance and scalability for applications running on those infrastructures, blocking the potential growth of a service, while using too much resource could create a cost that the application provider might not be able to afford, resulting indirectly on a loss of income in long-term.

On the same line, an infrastructure where runs a PostgreSQL cluster of nodes, with single master/multiple slave architecture, can be tricky to manage to not penalize the scalability and reliability of applications and services depending on it. Reliability can be achieved thanks to replication features of PostgreSQL combined with some external HA tools (Corosync, Pacemaker, etc.), and scalability, at least read, can be reached thanks the deployment of read-only slaves plugged into the master node (or even slave nodes with cascading). Keeping the balance between HA and scalability is delicate, and requires the expertise and experience of dedicated specialists.

Perhaps one of the most painful operations that usually needs to be done after the promotion of a slave node is re-purposing existing resources used by the old master node and have them reused to build a new slave that will be plugged once again in the cluster (after of course checking that the master did not fail because of a hardware failure or something else, but this is a different problem). If there is no recent base backup lying around, rebuilding a new slave node can require some time as taking a new fresh base backup with for example pg_basebackup can get long if the node that is going to be replicated has a large database size.

Recently, Heikki Linnakangas, supported by VMware, has built a new module for PostgreSQL called pg_rewind dedicated to accelerate the recycling of old master resources in an existing cluster by re-syncing its data folder with a method based on WAL record scan. The code of pg_rewind can be found [here](https://github.com/vmware/pg_rewind).

Simply, you cannot connect an old master (or referred below as **old node** below) back to an existing cluster node as-is (reconnection done to a promoted slave or another slave, referred below as **new node**), or its start-up will normally fail with the following kind of error:

    FATAL:  requested timeline 2 is not a child of this server's history
    DETAIL:  Latest checkpoint is at 0/4000028 on timeline 1, but in the history of the requested timeline, the server forked off from that timeline at 0/3023478

So what pg_rewind does to solve that is to send back in time the old node to the point where WAL files forked between the old node and the new node, this is the "rewind" operation. Once this has been done, the master can be restarted and it will replay WAL files until it gets in sync with the promoted slave. The method used with pg_rewind is interesting, and needs the data folder of the old node that be synced, plus the data folder or connection string to the new node going to be used as origin for the sync. Here are the main steps used to perform the rewind.

  * Scan data folder of old node from WAL fork point and record the blocks that have been touched
  * Copy changed blocks from new node to old node
  * Copy remaining files (clog, configuration files, etc.)
  * Set recovery.conf and restart the old node
  * WAL files are replayed starting from failover checkpoint

However, as a young project, pg_rewind has some limitations and has still some challenges to face. Among the things to know, here are the known limitations of this utility.

  * The use of checksums is mandatory for a simple reason: hint bits are not WAL-logged. Behind this obscure reason, imagine a transaction that begins before WAL fork and inserts some data on a given page. Then this transaction sets hint bits and commits after WAL fork. In this case the blocks changed are not taken into account, checksums (introduced in 9.3) become necessary to get a full page image directly in WAL records
  * The old node needs to be stopped cleanly. It might be possible to implement an option of the type --force, where even a failed node could be resync'ed. This looks difficult to do and could not even be solved in some cases like hardware failure... But let's see.
  * It might be necessary to copy WAL files necessary for replay manually
  * There is no tablespace support yet

Honestly, I think that this project has some potential and well, I'll spend some time hacking and improving it. Once those challenges are solved and pg_rewind grows a bit and becomes a mature solution, perhaps this could be someday included directly in Postgres core as a contrib module... But this is really another story.
