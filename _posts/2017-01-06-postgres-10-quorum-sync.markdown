---
author: Michael Paquier
lastmod: 2017-01-06
date: 2017-01-06 14:09:20+00:00
layout: post
type: post
slug: postgres-10-quorum-sync
title: 'Postgres 10 highlight - Quorum set of synchronous standbys'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- 10
- feature
- highlight
- replication
- wal
- synchronous
- quorum
- commit
- availability
- standby
- any
- first

---

Today's post, the first one of 2017, is about the following feature of the
upcoming Postgres 10:

    commit: 3901fd70cc7ccacef1b0549a6835bb7d8dcaae43
    author: Fujii Masao <fujii@postgresql.org>
    date: Mon, 19 Dec 2016 21:15:30 +0900
    Support quorum-based synchronous replication.

    This feature is also known as "quorum commit" especially in discussion
    on pgsql-hackers.

    This commit adds the following new syntaxes into synchronous_standby_names
    GUC. By using FIRST and ANY keywords, users can specify the method to
    choose synchronous standbys from the listed servers.

    FIRST num_sync (standby_name [, ...])
    ANY num_sync (standby_name [, ...])

    The keyword FIRST specifies a priority-based synchronous replication
    which was available also in 9.6 or before. This method makes transaction
    commits wait until their WAL records are replicated to num_sync
    synchronous standbys chosen based on their priorities.

    The keyword ANY specifies a quorum-based synchronous replication
    and makes transaction commits wait until their WAL records are
    replicated to *at least* num_sync listed standbys. In this method,
    the values of sync_state.pg_stat_replication for the listed standbys
    are reported as "quorum". The priority is still assigned to each standby,
    but not used in this method.

    The existing syntaxes having neither FIRST nor ANY keyword are still
    supported. They are the same as new syntax with FIRST keyword, i.e.,
    a priority-based synchronous replication.

    Author: Masahiko Sawada
    Reviewed-By: Michael Paquier, Amit Kapila and me
    Discussion: <CAD21AoAACi9NeC_ecm+Vahm+MMA6nYh=Kqs3KB3np+MBOS_gZg@mail.gmail.com>

    Many thanks to the various individuals who were involved in
    discussing and developing this feature.

9.6 has introduced the possibility to specify multiple synchronous standbys
by extending the syntax of
[synchronous\_standby\_names](https://www.postgresql.org/docs/devel/static/runtime-config-replication.html#runtime-config-replication-master).
For example values like 'N (standby\_1,standby\_2, ... ,standby\_M)' allow
a primary server to wait for commit confirmations from N standbys among the
set of M nodes defined in the list given by user, depending on the availability
of the standbys at the moment of the transaction commit, and their reported
WAL positions for write, apply or flush. In this case, though, the standbys
from which a confirmation needs to be waited for are chosen depending on their
order in the list of the parameter.

Being able to define quorum sets of synchronous standbys provides more
flexibility in some availability scenarios. In short, it is possible to
validate a commit after receiving a confirmation from N standbys, those
standbys being *any* node listed in the M nodes of synchronous\_standby\_names.
So this facility is actually useful for example in the case of deployments
where there is a primary with two or more standbys to bring more flexibility
in the way synchronous standbys are chosen. Be careful though that it is
better to have a low latency between each node, but there is nothing new
here...

In order to support this new feature, and as mentioned in the commit message,
the grammar of synchronous\_standby\_names has been extended with a set of
keywords.

  * ANY maps to the quorum behavior, meaning that any node in the set can be
  used to confirm a commit.
  * FIRST maps to the 9.6 behavior, giving priority to the nodes listed
  first (higher priority number defined).

Those can be used as follows:

    # Quorum set of two nodes
    any 2(node_1,node_2)
	# Priority set of two nodes, with three standbys
	first 1(node_1,node_2,node_3)

Note as well that not using any keyword means 'first' for
backward-compatibility. And that those keywords are case insensitive.

One last thing to know is that pg\_stat\_replication marks the standbys
in a quorum set with... 'quorum'. For example let's take a primary with
two standbys node\_1 and node\_2.

    =# ALTER SYSTEM SET synchronous_standby_names = 'ANY 2(node_1,node_2)';
    ALTER SYSTEM
    =# SELECT pg_reload_conf();
     pg_reload_conf
    ----------------
     t
    (1 row)

And here is how they show up to the user:

    =# SELECT application_name, sync_priority, sync_state FROM pg_stat_replication;
     application_name | sync_priority | sync_state
    ------------------+---------------+------------
     node_1           |             1 | quorum
     node_2           |             2 | quorum
    (2 rows)

Note that the priority number does not have much meaning for a quorum set,
though it is useful to see them if user is willing to switch from 'ANY'
to 'FIRST' to understand what would be the standbys that would be considered
as synchronous after the switch (this is still subject to discussions on
community side, and may change by the release of Postgres 10).
