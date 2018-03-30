---
author: Michael Paquier
lastmod: 2014-06-30
date: 2014-06-30 13:51:29+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-process-tracking-cluster-name
title: 'Postgres 9.5 feature highlight - Tracking processes with cluster_name'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.5
- monitoring

---
Here is a small feature that has showed up during the [first commit fest]
(https://commitfest.postgresql.org/action/commitfest_view?id=22) of
Postgres 9.5 allowing to add complementary information in the process
names displayed by a server:

    commit 51adcaa0df81da5e94b582d47de64ebb17129937
    Author: Andres Freund <andres@anarazel.de>
    Date:   Sun Jun 29 14:15:09 2014 +0200

    Add cluster_name GUC which is included in process titles if set.

    When running several postgres clusters on one OS instance it's often
    inconveniently hard to identify which "postgres" process belongs to
    which postgres instance.

    Add the cluster_name GUC, whose value will be included as part of the
    process titles if set. With that processes can more easily identified
    using tools like 'ps'.

    To avoid problems with encoding mismatches between postgresql.conf,
    consoles, and individual databases replace non-ASCII chars in the name
    with question marks. The length is limited to NAMEDATALEN to make it
    less likely to truncate important information at the end of the
    status.

    Thomas Munro, with some adjustments by me and review by a host of people.

This is helpful to identify to which server is attached a process when
running multiple instances on the same host, here is for example the case
of two nodes: a master and a standby (feel free to not believe that by the
way!).

    $ psql -At -p 5432 -c 'show cluster_name'
    master
    $ psql -At -p 5433 -c 'show cluster_name'
    standby
    $ ps x | grep "master\|standby" | grep -v 'grep'
    80624   ??  Ss     0:00.00 postgres: standby: logger process
    80625   ??  Ss     0:00.02 postgres: standby: startup process   recovering 000000010000000000000004
    80633   ??  Ss     0:00.01 postgres: standby: checkpointer process
    80634   ??  Ss     0:00.07 postgres: standby: writer process
    80635   ??  Ss     0:00.00 postgres: standby: stats collector process
    80655   ??  Ss     0:00.00 postgres: master: logger process
    80657   ??  Ss     0:00.01 postgres: master: checkpointer process
    80658   ??  Ss     0:00.07 postgres: master: writer process
    80659   ??  Ss     0:00.04 postgres: master: wal writer process
    80660   ??  Ss     0:00.02 postgres: master: autovacuum launcher process
    80661   ??  Ss     0:00.01 postgres: master: archiver process
    80662   ??  Ss     0:00.05 postgres: master: stats collector process
    80669   ??  Ss     0:00.76 postgres: standby: wal receiver process   streaming 0/4000428
    80670   ??  Ss     0:00.01 postgres: master: wal sender process postgres 127.0.0.1(55677) streaming 0/4000428

Non-ascii characters are printed as question marks.

    $ grep cluster_name $PGDATA/postgresql.conf
    cluster_name = 'éèê'
    $ ps x | grep postgres | head -n1
    81485   ??  Ss     0:00.00 postgres: ??????: logger process

For development purposes, this makes debugging easier...
