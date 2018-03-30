---
author: Michael Paquier
lastmod: 2016-04-13
date: 2016-04-13 00:15:34+00:00
layout: post
type: post
slug: postgres-9-6-feature-highlight-multi-sync-rep
title: 'Postgres 9.6 feature highlight - Multiple synchronous standbys'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.6
- wal
- synchronous

---

Among the features that are going to land with Postgres 9.6, here is a nice
one that is going to make users in charge of high-availability structures
quite happy, in short a lot:

    commit: 989be0810dffd08b54e1caecec0677608211c339
    author: Fujii Masao <fujii@postgresql.org>
    date: Wed, 6 Apr 2016 17:18:25 +0900
    Support multiple synchronous standby servers.

    Previously synchronous replication offered only the ability to confirm
    that all changes made by a transaction had been transferred to at most
    one synchronous standby server.

    [...]

    Authors: Sawada Masahiko, Beena Emerson, Michael Paquier, Fujii Masao
    Reviewed-By: Kyotaro Horiguchi, Amit Kapila, Robert Haas, Simon Riggs,
    Amit Langote, Thomas Munro, Sameer Thakur, Suraj Kharage, Abhijit Menon-Sen,
    Rajeev Rastogi

Behing this commit message wanted as incomplete for this post because it is
really long, hides the possibility to set up multiple synchronous standby
servers in a PostgreSQL cluster. Since 9.1, Postgres offers the possibility
to have one, unique, synchronous standby, which guarantees that a transaction
committed on a master node will never be lost on its synchronous standby node,
assuming that synchronous\_commit is set to 'on' (default), which ensures that
when the transaction is committed on the master node the commit WAL record
has been flushed to disk on the standby. Note that synchronous\_commit can be
set to some other values, feel free to have a look in the [documentation](http://www.postgresql.org/docs/devel/static/runtime-config-wal.html#GUC-SYNCHRONOUS-COMMIT)
and some explanation in [last post](/postgresql-2/postgres-9-6-feature-highlight-remote-apply/)
regarding another new feature of 9.6 for more details.

With this feature one can have multiple standbys that guarantee that no
transaction commit is lost on the way once committed on the master, giving
the possibility to handle multiple failures in a cluster. Note that as the
master needs to wait not for one, but for multiple standbys the confirmation
that the commit WAL record has been flushed to disk before letting the client
that the commit is finished localle, there is a performance penalty that
gets higher the more synchronous standbys are used.

And actually, this feature is really great when combined with the new
mode of synchronous\_commit called remote\_apply, because both features
combined give the possibility to have a true read balancing among N nodes
in a PostgreSQL cluster, and not only one. Some applications may want to
give priority to this read balancing instead of cluster availability.

In order to use this feature, the grammar of [synchronous\_standby\_names](http://www.postgresql.org/docs/devel/static/runtime-config-replication.html#GUC-SYNCHRONOUS-STANDBY-NAMES)
has been extended a bit with parenthesis separators, for example:

    'N (standby1, standby2, ... standbyM)'

This means that N nodes are tracked as synchronous among the set of M
standbys defined in the list. Note as well the following:

  * If N > M, all the nodes are considered as synchronous. And actually
  be careful not to do that, because this would make the code wait for
  nodes that do not exist. Note that when this happens the server generates
  a WARNING in its logs.
  * If N < M, the first N nodes listed and currently connected to a master
  node are considered as synchronous, and the rest are potential candidates
  to be synchronous.
  * If N = M, all the nodes are considered as synchronous
  * N = 1 is equivalent to the pre-9.5 grammar, the case where no parenthesis
  separators are used in the string value.

Now let's see the feature in action with one master and four standbys,
switching them so as 2 synchronous standbys are set with one standby that
could potentially become synchronous if one of the existing synchronous
nodes goes missing:

    =# ALTER SYSTEM SET synchronous_standby_names = '2(node_5433, node_5434, node_5435)';
    ALTER SYSTEM
    =# SELECT pg_reload_conf();
     pg_reload_conf
    ----------------
     t
    (1 row)
	=# SELECT application_name, sync_priority, sync_state
       FROM pg_stat_replication ORDER BY application_name;
     application_name | sync_priority | sync_state
    ------------------+---------------+------------
     node_5433        |             1 | sync
     node_5434        |             2 | sync
     node_5435        |             3 | potential
     node_5436        |             0 | async
	(4 rows)
    =# SHOW synchronous_commit;
     synchronous_commit
    --------------------
     on
    (1 row)

And done. With synchronous\_commit set to 'on', transaction commits are
guaranteed to not be lost on those two nodes, improving the whole system
availability.
