---
author: Michael Paquier
OBlastmod: 2015-11-06
date: 2015-11-06 13:02:11+00:00
layout: post
type: post
slug: pg-panic-robustness-testing
title: 'pg_panic to test deployment robustness with Postgres'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- postmaster
- robustness
- pg_panic
- panic
- extension
- luck
- factor
- crash
- application
- backend
- frontend

---

PostgreSQL is a piece of software known for its robustness, being something
reliable on which a complete infrastructure can be based to allow availability,
reliability and performance. However, sometimes things can go wrong, there
may be file-system or OS problems popping up, potentially corrupting a
database and forcing one to roll in a backup or to perform a failover to
another node. Sometimes, when studying the stability of a system, QE/QA
procedures involve making one piece or more of an infrastructure unstable
to test how other components can react to a failure and see if they can
properly recover from it.

Using the extensive infrastructure of PostgreSQL, here is [pg_panic]
(https://github.com/michaelpq/pg_plugins/tree/master/pg_panic) that is
aimed (somewhat) at bringing a bit of non-deterministic behavior in such
failures by triggering a PANIC, causing a server to crash immediately all
the backends, depending on a luck factor for all queries running through
the planner. This extension uses the internal hook at planner level
to do this check for all queries that need a plan, like SELECT, INSERT,
UPDATE and DELETE once per query executed from a frontend application
or client, protecting utility and DDL queries. OLTP applications are
more likely to trigger faster a failure than data warehouse type of
applications with long transactions, so one needs to be careful when
setting up the luck factor of this extension.

Enabling this extension can be done by either loading it on a backend
using LOAD, but the best way is surely to use this parameter in
postgresql.conf, then to start the server:

    shared_preload_libraries = 'pg_panic'

Then, the luck factor can be defined for a given backend or a server
level using the parameter called pg\_panic.luck\_factor whose range
of possible values is 0 to 1, 0 disabling completely the chance to
trigger a server-level crash, and 1, making it happening with 100%
of chances. See for example by yourself:

    =# SET pg_panic.luck_factor TO 1;
    SET
    =# SELECT 1;
    PANIC:  XX000: Jinx! Bad luck for today.
    LOCATION:  panic_hook, pg_panic.c:37
    server closed the connection unexpectedly
    This probably means the server terminated abnormally
    before or while processing the request.
    The connection to the server was lost. Attempting reset: Failed.

In this case server was likely to crash quickly, but using a very low
luck factor, depending on the number of queries happening in a system,
can be useful to leverage the timing when a crash would happen, 0.001
being the default. As postgres does not allow int64 as a type of custom
parameter (only int32 is allowed), perhaps it may be better to add
an extra layer of parametrization to lower the chances to trigger a crash,
as dozens of thousands of queries per seconds is something that is
common for deployments with Postgres, so even with a minimal value
of the luck factor a crash could happen within seconds.

You may want to use this extension, or not. Or preferably use it as an
example for more advanced and serious things. Special thanks to Nicolas
Thauvin and Julien Rouhaud for the esoteric discussions on the matter :)
