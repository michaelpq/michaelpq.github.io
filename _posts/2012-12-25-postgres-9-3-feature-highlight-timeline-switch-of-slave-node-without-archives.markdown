---
author: Michael Paquier
comments: false
lastmod: 2012-12-25
date: 2012-12-25 14:44:32+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-timeline-switch-of-slave-node-without-archives
title: 'Postgres 9.3 feature highlight - timeline switch of slave node without archives'
categories:
- PostgreSQL-2
tags:
- '9.1'
- '9.2'
- '9.3'
- database
- master
- open source
- postgres
- postgresql
- promote
- standby
- switch
- timeline
---

Since PostgreSQL 9.1, it is possible to switch a standby server to follow another server that has been freshly promoted after the master node of a cluster is out due to a failure (disaster or another). In this example, a master and two slaves are running on the same machine. The master running with port 5432 fails, Slave 1 is promoted as the new master:

    pg_ctl promote -D $SLAVE1_DATA

As the master is not accessible, Slave 2 is unable to keep pace in the cluster. So you need to update the following parameters of recovery.conf of Slave 2 as follows to reconnect it to the new master (which is now Slave 1):

    primary_conninfo = 'host=localhost port=5532 application_name=slave2
    recovery_target_time = 'latest'

Finally restart Slave 2 to continue recovery from the new master.

    pg_ctl restart -D $SLAVE2_DATA

When doing this in PostgreSQL 9.1 and 9.2, you need a WAL archive (archive\_mode = 'on' on all servers) to allow a standby to recover WAL files that are missing in order to complete the timeline change (please note that you can also copy the WAL files from the slave node directly). If no archive is available, a standby trying to reconnect to a promoted node will stop its recovery with those types of errors due to missing WAL information:

    FATAL:  timeline 2 of the primary does not match recovery target timeline 1

This can only be solved by copying the WAL segments from the master node or using a WAL archive.

However, in order to make Postgres cluster management far more flexible, the following feature has been developed for 9.3:

    commit abfd192b1b5ba5216ac4b1f31dcd553106304b19
    Author: Heikki Linnakangas <heikki.linnakangas@iki.fi>
    Date:   Thu Dec 13 19:00:00 2012 +0200

    Allow a streaming replication standby to follow a timeline switch.

    Before this patch, streaming replication would refuse to start replicating
    if the timeline in the primary doesn't exactly match the standby. The
    situation where it doesn't match is when you have a master, and two
    standbys, and you promote one of the standbys to become new master.
    Promoting bumps up the timeline ID, and after that bump, the other standby
    would refuse to continue.

    There's significantly more timeline related logic in streaming replication
    now. First of all, when a standby connects to primary, it will ask the
    primary for any timeline history files that are missing from the standby.
    The missing files are sent using a new replication command TIMELINE_HISTORY,
    and stored in standby's pg_xlog directory. Using the timeline history files,
    the standby can follow the latest timeline present in the primary
    (recovery_target_timeline='latest'), just as it can follow new timelines
    appearing in an archive directory.

    START_REPLICATION now takes a TIMELINE parameter, to specify exactly which
    timeline to stream WAL from. This allows the standby to request the primary
    to send over WAL that precedes the promotion. The replication protocol is
    changed slightly (in a backwards-compatible way although there's little hope
    of streaming replication working across major versions anyway), to allow
    replication to stop when the end of timeline reached, putting the walsender
    back into accepting a replication command.

    Many thanks to Amit Kapila for testing and reviewing various versions of
    this patch.

This feature allows to switch to the latest timeline on a standby server just by using streaming replication, a WAL archive becoming non-mandatory (archive\_mode = 'off' on all servers). In order to complete that, a new streaming replication command called TIMELINE\_HISTORY has been created, which makes the standby recover all the missing timeline history files from the node it connects to, facilitating the switch to the latest timeline available.

When timeline history files are requested from another node, the following things are logged:

    LOG:  fetching timeline history file for timeline 2 from primary server
    LOG:  started streaming WAL from primary at 0/5000000 on timeline 1
    LOG:  replication terminated by primary server
    DETAIL:  End of WAL reached on timeline 1
    LOG:  restarted WAL streaming at 0/5000000 on timeline 2

Removing the obligation to use WAL archives really brings more flexibility in a PostgreSQL cluster, making this feature a non-negligible must-have, especially when thinking about cascading nodes. However, having that does not mean that you should bypass the use of WAL archives, so be sure to tune your system depending on the needs of your applications.
