---
author: Michael Paquier
lastmod: 2015-09-30
date: 2015-09-30 04:10:43+00:00
layout: post
type: post
slug: track-commit-synchronous
title: 'Detection of COMMIT queries stuck because of synchronous replication in Postgres'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- replication
- synchronous
- monitoring

---

Since its introduction in 9.1, [synchronous replication]
(http://www.postgresql.org/docs/devel/static/warm-standby.html#SYNCHRONOUS-REPLICATION),
or the ability to wait for a WAL flush confirmation from a standby before
committing a transaction on the master node (depends on synchronous\_commit
whose default value is on), ensuring that the transaction committed has not
been lost on the standby should a failover need to be done, has faced a wide
adoption in many production environments for applications that need a
no-data-loss scenario. Still, such application or clients may have seen something
like that:

    =# COMMIT;
    Cancel request sent
    WARNING:  01000: canceling wait for synchronous replication due to user request
    DETAIL:  The transaction has already committed locally, but might not have been replicated to the standby.
    LOCATION:  SyncRepWaitForLSN, syncrep.c:217
    COMMIT

What happens here is that the commit query has remained stuck for a couple
of seconds because it was keeping waiting for the flush confirmation that
was not coming. Depending on the outage of the standby, this could take a
while, so here what happened is that the query has been manually cancelled,
then transaction has been committed on the master without the confirmation
coming from the standby. One of the ways to check if a backend is being
stuck similarly to the above is to have a look at the output of ps, to find
something like that:

    $ ps x | grep postgres | grep waiting
    15323   ??  Ss     0:00.06 postgres: easteregg easteregg [local] COMMIT waiting for 0/1797488

But that's not particularly useful when user is not able to connect directly
to the node involved (usually that should be the case for a superuser of
this database instance), and the catalog table pg\_stat\_activity does not
offer a way to know if the backend is really stuck at commit because of
synchronous replication or because of another lock.

    =# SELECT pid, state, waiting FROM pg_stat_activity
       WHERE lower(query) = 'commit;';
      pid  | state  | waiting
    -------+--------+---------
     15323 | active | f
    (1 row)

Note that there is a [patch submitted for integration to Postgres 9.6]
(http://www.postgresql.org/message-id/CA+TgmoYd3GTz2_mJfUHF+RPe-bCy75ytJeKVv9x-o+SonCGApw@mail.gmail.com)
to make this information more verbose, something particularly interesting
is that it would be possible to track the type of lock a backend is being
stuck on, in our case that would be SyncRepLock. Still, this does not offer
a solution for the existing deployments of 9.1 and newer versions, so I
hacked out an extension that has a look at the backend array and returns
the on-memory information regarding their synchronous replication state.
The utility, called [pg\_syncrep\_state](https://github.com/michaelpq/pg_plugins/tree/master/pg_rep_state)
is available in [pg\_plugins](https://github.com/michaelpq/pg_plugins)
under the PostgreSQL license. Once compiled and installed, for example
in the case of the backend stuck above, it is possible to get a precise
report of its state regarding synchronous replication.

    =# \dx+ pg_rep_state
    Objects in extension "pg_rep_state"
          Object Description
    -----------------------------
     function pg_syncrep_state()
     view pg_syncrep_state
    (2 rows)
    =# SELECT * FROM pg_syncrep_state WHERE pid = 15323;
      pid  | wait_state | wait_lsn
    -------+------------+-----------
     15323 | waiting    | 0/1797488
    (1 row)

An interesting use case of this utility is for example to join it with
pg\_stat\_activity to do some decisions for the backends stuck for more
than a given amount of time, say for example this query to retrieve the
list of PIDs being stuck in a waiting state because of synchronous
replication for more than 10 seconds:

    =# SELECT a.pid
       FROM pg_syncrep_state s
         JOIN pg_stat_activity a ON (a.pid = s.pid)
       WHERE s.wait_state = 'waiting' AND now() - query_start > interval '10s';
      pid
    -------
     15323
    (1 row)

Then by for example using pg\_cancel\_backend it is possible to enforce
the commit of the stuck transaction, resulting in the following for the
backend process targetted.

    =# COMMIT;
    WARNING:  01000: canceling wait for synchronous replication due to user request
    DETAIL:  The transaction has already committed locally, but might not have been replicated to the standby.
    LOCATION:  SyncRepWaitForLSN, syncrep.c:217
    COMMIT

More fancy things could be done though by for example switching the server
back to asynchronous replication by disabling synchronous\_standby\_names,
the decision making happening with libpq without looking at the display of
ps. ALTER SYSTEM in combination with pg\_reload\_conf() could also be used
to leverage that without logging into a server at the OS level.
