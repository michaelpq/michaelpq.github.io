---
author: Michael Paquier
lastmod: 2019-07-22
date: 2019-07-22 08:26:42+00:00
layout: post
type: post
slug: postgres-12-recovery-change
title: 'Postgres 12 highlight - Recovery changes'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 12
- recovery

---

PostgreSQL 12 has changed the way recovery configuration works,
and has introduced a couple of incompatible issues as mentioned
in the main commit which has done the switch:

    commit: 2dedf4d9a899b36d1a8ed29be5efbd1b31a8fe85
    author: Peter Eisentraut <peter_e@gmx.net>
    date: Sun, 25 Nov 2018 16:31:16 +0100
    Integrate recovery.conf into postgresql.conf

    recovery.conf settings are now set in postgresql.conf (or other GUC
    sources).  Currently, all the affected settings are PGC_POSTMASTER;
    this could be refined in the future case by case.

    Recovery is now initiated by a file recovery.signal.  Standby mode is
    initiated by a file standby.signal.  The standby_mode setting is
    gone.  If a recovery.conf file is found, an error is issued.

    The trigger_file setting has been renamed to promote_trigger_file as
    part of the move.

    The documentation chapter "Recovery Configuration" has been integrated
    into "Server Configuration".

    pg_basebackup -R now appends settings to postgresql.auto.conf and
    creates a standby.signal file.

    Author: Fujii Masao <masao.fujii@gmail.com>
    Author: Simon Riggs <simon@2ndquadrant.com>
    Author: Abhijit Menon-Sen <ams@2ndquadrant.com>
    Author: Sergei Kornilov <sk@zsrv.org>
    Discussion: https://www.postgresql.org/message-id/flat/607741529606767@web3g.yandex.ru/

From the point of view of code and maintenance, this has the huge advantage
of removing the duplication caused by the parsing of recovery.conf which
followed its own set of rules that were rather close to what is used for
the generic GUC parameters, and this adds all the benefits behind GUCs, as
it becomes possible:

  * To reload parameters.
  * To monitor the values with SHOW.
  * To apply changes with ALTER SYSTEM.

However this introduces a set of compatibility changes to be aware of in
order to adapt to the new rules.

First note that upgrading a standby instance to 12 and newer versions will
cause an immediate failure, as the startup process would complain about the
presence of recovery.conf:

    FATAL:  using recovery command file "recovery.conf" is not supported
    LOG:  startup process (PID 28201) exited with exit code 1

Here is a note about the backward-incompatible changes done:

  * standby\_mode has been removed from the parameters, and is replaced
  by an on-disk file called standby.signal as it represents a state of
  the cluster, so a configuration parameter does not map completely with
  its role.
  * trigger\_file is renamed to promote\_trigger\_file.
  * pg\_basebackup -R generated recovery.conf, and now all the parameters
  are written to postgresql.auto.conf instead which is used by ALTER
  SYSTEM by default.

In the background, nothing much changes as even if all the recovery-related
values are available in the GUC context of a session, only the startup
process makes use of it.

In the initial implementation, all the parameters were marked as
PGC\_POSTMASTER, meaning that they could just be loaded at server start time,
and an update required a server restart to be effective.  An additional
improvements has made some of those parameters as reloadable, which is an
upgrade compared to past versions of PostgreSQL.  Here are the parameters
concerned:

  * archive\_cleanup\_command, to control the way past WAL segments are cleaned
  up, useful to control retention of the WAL archives depending on how much
  a standby feeds from it.
  * promote\_trigger\_file, the file checked after to end recovery and promote
  a cluster as a new primary with a timeline bump.
  * recovery\_end\_command.  Note here that this command is only triggered
  once at the end of recovery, but it can be useful to update it on a
  set of standbys if migrating a configuration.
  * recovery\_min\_apply\_delay, which is very useful to tune the requests
  done to check when WAL is available, and when recovering from the
  archives this can be tuned dynamically to control the requests to a
  server where WAL archives are located.

There are plans to make more parameters reloadable, particularly
primary\_conninfo.  This could not make it to PostgreSQL 12, and is
much trickier than the others as this requires changes around the way
a WAL receiver spawn request is done from the startup process.
