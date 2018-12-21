---
author: Michael Paquier
lastmod: 2018-12-21
date: 2018-12-21 05:04:27+00:00
layout: post
type: post
slug: postgres-12-wal-sender-userset
title: 'Postgres 12 highlight - wal_sender_timeout now user-settable'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 12
- guc
- replication
- tuning
- wal

---

The following commit has reached PostgreSQL 12, which brings more flexibility
in managing replication with standbys distributed geographically:

    commit: db361db2fce7491303f49243f652c75c084f5a19
    author: Michael Paquier <michael@paquier.xyz>
    date: Sat, 22 Sep 2018 15:23:59 +0900
    Make GUC wal_sender_timeout user-settable

    Being able to use a value that can be changed on a connection basis is
    useful with clusters distributed geographically, and makes failure
    detection more flexible.  A note is added in the documentation about the
    use of "options" in primary_conninfo, which can be hard to grasp for
    newcomers with the need of two single quotes when listing a set of
    parameters.

    Author: Tsunakawa Takayuki
    Reviewed-by: Masahiko Sawada, Michael Paquier
    Discussion: https://postgr.es/m/0A3221C70F24FB45833433255569204D1FAAD3AE@G01JPEXMBYT05

For some deployments, it matters to be able to change
[wal\_sender\_timeout](https://www.postgresql.org/docs/devel/runtime-config-replication.html#RUNTIME-CONFIG-REPLICATION-SENDER)
depending on the standby and the latency with its primary (or another standby
when dealing with a cascading instance).  For example, a shorter timeout
for a standby close to its primary allows faster problem detection and
failover, while a longer timeout can become helpful for a standby in a remote
location to judge correctly its health.  In Postgres 11 and older versions,
and this since wal\_sender\_timeout has been introduced since 9.1, this
parameter can only be set at server-level, being marked as PGC\_SIGHUP in its
GUC properties.  Changing the value of this parameter does not need an
instance restart and the new value can be reloaded to all the sessions
connected, including WAL senders.

The thread related to the above commit has also discussed if this parameter
should be changed to be a backend-level parameter, which has the following
properties:

  * Reload does not work on it.  Once this parameter is changed at
  connection time it can never change.
  * Changing this parameter at server level will make all new connections
  using the new value.
  * Role-level configuration is not possible.

Still, for default values, it is a huge advantage to be able to reload
on-the-fly wal\_sender\_timeout depending on the state of an environment.
So the choice has been made to make the parameter user-settable with
PGC\_USERSET so as it is possible to have values set up depending on the
connected role (imagine different policies per role), and to allow the
parameter to be reloaded for all sessions which do not enforce it at
connection level.  Coming back to the connection, the main advantage
is that the value can be enforced using two different methods in
primary\_conninfo.  First, and as mentioned previously, by connecting
with a role which has a non-default value associated with it (this can
be configured with ALTER ROLE).  The second way is to pass directly
the parameter "options" in a connection string, so as the following
configuration gets used (single quotes are important!):

    primary_conninfo = ' options=''-c wal_sender_timeout=60000'' ...'

Note as well that the SHOW command works across the replication
protocol (since Postgres 10), so as it is possible to also check the
effective value of a parameter at application level.  Of course this
is available for anything using the replication protocol, like a WAL
archiver using pg\_receivewal, logical workers, etc.

Making wal\_sender\_timeout configuration more flexible is extremely
useful for many experienced users, so this is a great addition to
Postgres 12.
