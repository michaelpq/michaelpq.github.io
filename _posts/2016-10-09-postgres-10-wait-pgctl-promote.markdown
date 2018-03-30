---
author: Michael Paquier
lastmod: 2016-10-09
date: 2016-10-09 05:50:22+00:00
layout: post
type: post
slug: postgres-10-wait-pgctl-promote
title: 'Postgres 10 highlight - Wait mode for pg_ctl promote'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 10
- pg_ctl
- monitoring

---

[pg_ctl](https://www.postgresql.org/docs/9.6/static/app-pg-ctl.html) is a
control utility on top of the postgres binary allowing to do many operations
on a server. A couple of its subcommands offer a way to wait for the operation
to finish before exiting pg\_ctl, which is useful to ensure the state of the
server before moving on with other things in the upper application layer.
Sub-commands start, restart and register (Windows-only to register Postgres
as a service in the in-core SCM), are not waited to finish by default, but
this can be done by using the -w switch. Reversely, the sub-command stop
implies to wait, and this can be disabled by using the switch -W. In Postgres
10, the sub-command promote has gained this option, per the following commit:

    commit: e7010ce4794a4c12a6a8bfb0ca1de49b61046847
    author: Peter Eisentraut <peter_e@gmx.net>
    date: Wed, 21 Sep 2016 12:00:00 -0400
    pg_ctl: Add wait option to promote action

    When waiting is selected for the promote action, look into pg_control
    until the state changes, then use the PQping-based waiting until the
    server is reachable.

Before this commit, what pg\_ctl did was to just write in PGDATA a file
called "promote" to let the startup process know that it needs to exit
recovery, to take a couple of end-of-recovery action, and to jump to a new
timeline before switching the server to read-write mode. Once pg\_ctl was
done, it was necessary to have some additional logic for example querying
pg\_is\_in\_recovery() on the newly-promoted server to see if the server
was ready for read-write queries or not. While not complicated, that is
always an additional task to do for the server maintainer when doing a
failover.

With pg\_ctl promote -w, such additional logic becomes unnecessary and
the whole process is actually more responsive. pg\_ctl checks periodically
for the control file of the server and see if it has been switched to an
in-production state, then it considers that the promotion is completed,
a check happening every second until a timeout ends (can be defined by
the user). However, the control file is updated closer to the point
where the backends are told that they are authorized to generate WAL,
as improved by
[this commit](http://git.postgresql.org/pg/commitdiff/ebdf5bf7d1c97a926e2b0cb6523344c2643623c7).

Even if pg\_ctl is not used, and some custom utility is in charge of
telling a Postgres instance to perform an upgrade, looking directly at
the on-disk contents of the control file would improve the responsiveness
and the reliability of the promotion process. Something to keep in mind
when working on your cluster management tools.
