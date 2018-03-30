---
author: Michael Paquier
lastmod: 2016-04-05
date: 2016-04-05 13:01:17+00:00
layout: post
type: post
slug: postgres-9-6-feature-highlight-remote-apply
title: 'Postgres 9.6 feature highlight - read balancing with remote_apply'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.6
- lsn
- wal
- synchronous

---

While the last commit fest of PostgreSQL 9.6 is moving to an end with a
soon-to-come [feature freeze](http://www.postgresql.org/message-id/CA+TgmoY56w5FOzeEo+i48qehL+BsVTwy-Q1M0xjUhUCwgGW7-Q@mail.gmail.com),
here is a short story about one of the features that got committed close
to the end of it:

    commit: 314cbfc5da988eff8998655158f84c9815ecfbcd
    author: Robert Haas <rhaas@postgresql.org>
    date: Tue, 29 Mar 2016 21:29:49 -0400
    Add new replication mode synchronous_commit = 'remote_apply'.

    In this mode, the master waits for the transaction to be applied on
    the remote side, not just written to disk.  That means that you can
    count on a transaction started on the standby to see all commits
    previously acknowledged by the master.

    To make this work, the standby sends a reply after replaying each
    commit record generated with synchronous_commit >= 'remote_apply'.
    This introduces a small inefficiency: the extra replies will be sent
    even by standbys that aren't the current synchronous standby.  But
    previously-existing synchronous_commit levels make no attempt at all
    to optimize which replies are sent based on what the primary cares
    about, so this is no worse, and at least avoids any extra replies for
    people not using the feature at all.

    Thomas Munro, reviewed by Michael Paquier and by me.  Some additional
    tweaks by me.

Up to 9.5, the GUC parameter synchronous\_commit, which defines the way a
commit behaves regarding WAL, is able to use the following values:

  * 'on', the default and safe case where a transaction will wait for its
  commit WAL record to be written to disk before sending back an acknoledgement
  to the client. When synchronous\_standby\_names is used, on top of waiting
  for the local WAL record to be flushed to disk, the confirmation that the
  synchronous standby has flushed it as well is waited.
  * 'off', where no wait is done. So there can be a delay between the moment
  a transaction is marked as committed and the moment its commit is recorded
  to disk.
  * 'remote_write', when synchronous\_standby\_names is in use, the
  confirmation from the synchronous standby that the record has been written
  to storage is waited for. There is no guarantee that the record has been
  flushed to stable storage though.
  * 'local', when synchronous\_standby\_names is in use, process only
  waits for the flush of the local WAL record to happen locally.

9.6 is going to have a new mode: remote\_apply. With this new value, should
synchronous\_standby\_names be in use, not only the flush confirmation of the
commit WAL record is waited for, but it is waited that the record has been
replayed by the synchronous standby. This simply allows read-balancing
consistency, because this way it is guaranteed that a session committing
a transaction on a master node will be visible for sessions on the standby
once it has been committed locally.

Before this feature, any application willing to do consistent read-balancing
across nodes have to juggle with the WAL record of the transaction commit and
add some processing at application level to ensure that a record has been
applied before ensuring that a given transaction data is visible on a
standby node. So this feature is quite a big deal for application relying on
read scalability across nodes.

Note that only one synchronous standby can be used with this mode though,
hence consistent reads can only be done on two nodes. This limitation
may be leveraged with some other features that are still on track for a 9.6
integration, even if the feature freeze is really close by at the moment
this post is written:

  * Causal reads, which provides a similar way to have balanced reads across
  nodes, with still the possibility to not see a transaction being visible
  up to a certain amount of lag. See [this thread](CAEepm=0n_OxB2_pNntXND6aD85v5PvADeUY8eZjv9CBLk=zNXA@mail.gmail.com).
  * N-synchronous standbys, which is more simple in itself, because this
  allows a system to scale from 1 to N synchronous standbys. Things like
  quorum synchronous standbys are being evaluated as well, with an elegant
  design. (However note that the more standbys they are, the more the
  performance penalty when waiting for them with remote\_apply). Everything
  is happening on [this thread](http://www.postgresql.org/message-id/CAB7nPqSJgDLLsVk_Et-O=NBfJNqx3GbHszCYGvuTLRxHaZV3xQ@mail.gmail.com)
  lately.

However, be careful when using remote\_apply. As it interacts with WAL
replay, it should not be taken lightly because it could cause performance
damages that you would not have imagined first, particularly in case of
replay conflicts that could force a standby to wait at replay. This is true
for any parameters manipulating how WAL replay behave by the way, another
example being recovery\_min\_apply\_delay. If for example this is set to
N seconds, a commit on master is sure to take at least this amount of
time.
