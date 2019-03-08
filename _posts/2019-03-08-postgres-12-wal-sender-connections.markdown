---
author: Michael Paquier
lastmod: 2019-03-08
date: 2019-03-08 07:28:51+00:00
layout: post
type: post
slug: postgres-12-wal-sender-connections
title: 'Postgres 12 highlight - Connection slots and WAL senders'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 12
- wal
- replication
- connection

---

The maximum number of connections a PostgreSQL can accept is configured using
[max\_connections](https://www.postgresql.org/docs/devel/runtime-config-connection.html#RUNTIME-CONFIG-CONNECTION-SETTINGS).
When attempting to connect to a server already at full capacity, logically the
server complains:

    $ psql
    psql: FATAL:  sorry, too many clients already

It is possible to define connection policies, for example at database level
with [CREATE DATABASE](https://www.postgresql.org/docs/devel/sql-createdatabase.html)
or [ALTER DATABASE](https://www.postgresql.org/docs/devel/sql-alterdatabase.html),
and even have superuser-only connection slots using
superuser\_reserved\_connections, so as a superuser has a reserved space
to be able to perform some activities even with a server full.

When creating a connection for replication purposes, the connection is spawned
under a special status with the context of a WAL sender which is in charge
of the communication, and speaks the
[replication protocol](https://www.postgresql.org/docs/devel/protocol-replication.html),
so as it is possible to do replication, to take base backups, etc.  A lot of
those tasks are important for availability.  One problem however is that this
connection uses a shared memory slot which is part of max\_connections.
Hence, it is possible to get into a case where an application bloats the
connections, and it becomes impossible to connect with a replication
connection.  This can be rather bad for availability, because this could
the creation of a new standby after a failover for example.

One way to counter that is to connect to the server for base backups and
standbys with a superuser role.  Still this is not completely right either
as by design there can be replication roles, which allow a role to connect
to a server in replication mode, without being a superuser.  In this context,
this is where the following commit of Postgres 12 becomes handy:

    commit: ea92368cd1da1e290f9ab8efb7f60cb7598fc310
    author: Michael Paquier <michael@paquier.xyz>
    date: Tue, 12 Feb 2019 10:07:56 +0900
    Move max_wal_senders out of max_connections for connection slot handling

    Since its introduction, max_wal_senders is counted as part of
    max_connections when it comes to define how many connection slots can be
    used for replication connections with a WAL sender context.  This can
    lead to confusion for some users, as it could be possible to block a
    base backup or replication from happening because other backend sessions
    are already taken for other purposes by an application, and
    superuser-only connection slots are not a correct solution to handle
    that case.

    This commit makes max_wal_senders independent of max_connections for its
    handling of PGPROC entries in ProcGlobal, meaning that connection slots
    for WAL senders are handled using their own free queue, like autovacuum
    workers and bgworkers.

    One compatibility issue that this change creates is that a standby now
    requires to have a value of max_wal_senders at least equal to its
    primary.  So, if a standby created enforces the value of
    max_wal_senders to be lower than that, then this could break failovers.
    Normally this should not be an issue though, as any settings of a
    standby are inherited from its primary as postgresql.conf gets normally
    copied as part of a base backup, so parameters would be consistent.

    Author: Alexander Kukushkin
    Reviewed-by: Kyotaro Horiguchi, Petr Jelínek, Masahiko Sawada, Oleksii
    Kliukin
    Discussion: https://postgr.es/m/CAFh8B=nBzHQeYAu0b8fjK-AF1X4+_p6GRtwG+cCgs6Vci2uRuQ@mail.gmail.com

The commit message explains that rather well (hopefully, guess who wrote
it!), and allows system administrators to have connection slots reserved
for replication roles so that the previous set of issues described in this
post does not cause problems.  In consequence, Postgres 12 is able to fully
separate application-related connections and connections aimed at being
used for base backups and replication, removing the need to use a connection
slot reserved for superusers for this purpose.  Note that this applies as
well to logical replication as the publication-side uses a connection in
replication mode.  As the maximum number of replication connections is
controlled in shared memory with max\_wal\_senders, the implementation
is just reusing this parameter to control the number of connection slots
available, so the conclusion around the proposed patch was that there
is no need for a new, different configuration parameter

One thing to note is that this has a cost in the shape of a potential
backward breakage as the standby needs to have max\_wal\_senders set to
a higher value than its primary, or it will complain at startup, which
is something that already happens for other parameters at recovery like
max\_connections.  So if you use a failover solution which enforced
max\_wal\_senders to a lower value than the origin, things could break.
Normally this should not be an issue though, as the value of the parameter
gets inherited in the initial base backup of the primary instance.
