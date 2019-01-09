---
author: Michael Paquier
lastmod: 2019-01-09
date: 2019-01-09 05:32:42+00:00
layout: post
type: post
slug: postgres-12-promote-function
title: 'Postgres 12 highlight - pg_promote'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 12
- recovery
- replication
- wal

---

The [following commit](https://git.postgresql.org/pg/commitdiff/10074651e3355e2405015f6253602be8344bc829)
has been merged into Postgres 12 a couple of months ago, easing failover
control flow:

    commit: 10074651e3355e2405015f6253602be8344bc829
    author: Michael Paquier <michael@paquier.xyz>
    date: Thu, 25 Oct 2018 09:46:00 +0900
    Add pg_promote function

    This function is able to promote a standby with this new SQL-callable
    function.  Execution access can be granted to non-superusers so that
    failover tools can observe the principle of least privilege.

    Catalog version is bumped.

    Author: Laurenz Albe
    Reviewed-by: Michael Paquier, Masahiko Sawada
    Discussion: https://postgr.es/m/6e7c79b3ec916cf49742fb8849ed17cd87aed620.camel@cybertec.at

Promotion is a process which can be used on a standby server to end recovery
and allow it to begin read-write operations, bumping this standby server to
a new timeline on the way.  This operation can be done using a couple of
options:

  * pg\_ctl promote, which waits for the standby to finish the promotion
  before exiting by default.
  * Define promote\_trigger\_file in postgresql.conf and create the file which
  would be detected by the startup process and translated so as recovery
  finishes (or trigger\_file in recovery.conf up to v11, recovery parameters
  being merged to postgresql.conf in v12 and newer versions).

The commit mentioned above offers a third way to trigger a promotion with a
SQL-callable function, which presents a huge advantage compared to the two
other methods: there is no need to connect to the standby physical host to
trigger the promotion as everything can be done with a backend session.  Note
however that this needs a standby server able to accept read-only operations
and connections.

By default pg\_promote() waits for the promotion to complete before returning
back its result to its caller, waiting for a maximum of 60 seconds, which is
the same default as the promote mode of pg\_ctl.  However it is possible to
enforce both the wait mode and the timeout value by specifying the wait mode
as a boolean for the first argument, and the timeout as an integer in seconds
for the second argument.  If the wait mode is false, then the timeout has no
effect and pg\_promote returns immediately once the promotion signal is sent
to the postmaster:

    -- Wait for at most 30 seconds.
    SELECT pg_promote(true, 30);
    -- Leave immediately without waiting.
    SELECT pg_promote(false);

Note that by default this function access is restricted to superusers, but its
execution can be granted directly to non superusers, leveraging failover with
a role dedicated only to promotion:

    =# CREATE ROLE promote_role LOGIN;
    CREATE ROLE
    =# GRANT EXECUTE ON FUNCTION pg_promote TO promote_role;
    GRANT

The function also returns a status as a boolean, false being a failure in
sending SIGUSR1 to the postmaster and true a success in finishing the
promotion (in non-wait mode, true is returned immediately), which makes it
easier to parse and handle the status by SQL clients.  Note as well a couple
of failures when attempting to:

  * define a negative number for the timeout.
  * trigger the function with a server not in recovery.
  * create the trigger file.

The function is also marked parallel-safe as it does not rely on any global
status shared across the server among processes, so it can be triggered in
parallel executions, still it may result in an error for some calls depending
on the timing between the parallel workers.  As this function should be
included in very simple SQLs, that's not really something to worry about
though.
