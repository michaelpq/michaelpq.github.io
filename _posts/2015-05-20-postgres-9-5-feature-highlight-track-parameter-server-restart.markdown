---
author: Michael Paquier
lastmod: 2015-05-20
date: 2015-05-20 03:05:12+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-track-parameter-server-restart
title: 'Postgres 9.5 feature highlight - Tracking parameters waiting for server restart'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.5
- monitoring
- log

---

A couple of days back the following commit has landed in the Postgres world,
for the upcoming 9.5 release:

    commit: a486e35706eaea17e27e5fa0a2de6bc98546de1e
    author: Peter Eisentraut <peter_e@gmx.net>
    date: Thu, 14 May 2015 20:08:51 -0400
    Add pg_settings.pending_restart column

    with input from David G. Johnston, Robert Haas, Michael Paquier

Particularly useful for system doing a lot of [server parameter]
(http://www.postgresql.org/docs/devel/static/runtime-config.html) updates,
this allows tracking parameters in need of a server restart when their
value is updated to have the new value take effect on the system.
Note that this applies to all the parameters marked as PGC_POSTMASTER
in guc.c, shared\_buffers being one, as well as the custom parameters a
system may have after their load by a plugin. This information is tracked
by a new column called pending\_restart in the system view [pg\_settings]
(http://www.postgresql.org/docs/devel/static/view-pg-settings.html) with
a boolean value set to "true" if a given GUC parameter is indeed waiting for
a server restart.

In order to make visible the fact that parameter waits for a restart, the
server can have its parameters be reloaded with either pg\_reload\_conf(),
"pg_ctl reload" or a SIGHUP signal. Of course, modifications made in
postgresql.conf, as well as any configuration files included, or ALTER SYSTEM
are taken into account. See for example:

    =# \! echo "port = 6666" > $PGDATA/postgresql.conf
    =# ALTER SYSTEM SET shared_buffers TO '1GB';
    ALTER SYSTEM
    =# SELECT pg_reload_conf();
     pg_reload_conf
    ----------------
     t
    (1 row)
    =# SELECT name FROM pg_settings WHERE pending_restart;
          name
    ----------------
     port
     shared_buffers
    (2 rows)

This will prove to be useful for many systems around, like those doing
automatic tuning of system parameters or even containers (not limited to
it of course).
