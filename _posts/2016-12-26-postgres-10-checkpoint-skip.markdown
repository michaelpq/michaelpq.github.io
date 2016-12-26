---
author: Michael Paquier
lastmod: 2016-12-26
date: 2016-12-26 08:19:54+00:00
layout: post
type: post
slug: postgres-10-checkpoint-skip
title: 'Postgres 10 highlight - Checkpoint skip logic'
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
- checkpoint
- wal
- important
- activity
- skip
- idle
- embedded
- system
- spike

---

It is too late for stories about Christmas, so here is a Postgres story
about the following commit of Postgres 10:

    commit: 6ef2eba3f57f17960b7cd4958e18aa79e357de2f
    author: Andres Freund <andres@anarazel.de>
    date: Thu, 22 Dec 2016 11:31:50 -0800
    Skip checkpoints, archiving on idle systems.

    Some background activity (like checkpoints, archive timeout, standby
    snapshots) is not supposed to happen on an idle system. Unfortunately
    so far it was not easy to determine when a system is idle, which
    defeated some of the attempts to avoid redundant activity on an idle
    system.

    To make that easier, allow to make individual WAL insertions as not
    being "important". By checking whether any important activity happened
    since the last time an activity was performed, it now is easy to check
    whether some action needs to be repeated.

    Use the new facility for checkpoints, archive timeout and standby
    snapshots.

    The lack of a facility causes some issues in older releases, but in my
    opinion the consequences (superflous checkpoints / archived segments)
    aren't grave enough to warrant backpatching.

    Author: Michael Paquier, editorialized by Andres Freund
    Reviewed-By: Andres Freund, David Steele, Amit Kapila, Kyotaro HORIGUCHI
    Bug: #13685
    Discussion:
    https://www.postgresql.org/message-id/20151016203031.3019.72930@wrigleys.postgresql.org
    https://www.postgresql.org/message-id/CAB7nPqQcPqxEM3S735Bd2RzApNqSNJVietAC=6kfkYv_45dKwA@mail.gmail.com
    Backpatch: 

Postgres 9.0 has been the first release to introduce the parameter
[wal\_level](https://www.postgresql.org/docs/devel/static/runtime-config-wal.html#runtime-config-wal-settings),
with three different values:

  * "minimal", to get enough information WAL-logged to recover from a crash.
  * "archive", to be able to recover from a base backup and archives.
  * "hot\_standby", to be able to have a standby node work, resulting in
  information about exclusive locks and currently running transactions
  to be WAL-logged, called standby snapshots.
  * "logical", introduced in 9.4, to work with logical decoding.

In 9.6, "archive" and "hot\_standby" have been merged into "replica" as
both levels have no difference in terms of performance. Another thing to
know is that standby snapshots are generated more often since 9.3 via the
bgwriter process, every 15 seconds to be exact.

So what is the commit above about? The fact that since "hot\_standby" has
been introduced the logic that was present in xlog.c to decide if checkpoints
should be skipped or not was simply broken. As "hot\_standby" has become a
standard in terms of configuration, many installations have been producing
useless checkpoints, or even useless WAL segments if archive\_timeout was
being set. This is actually no big deal for most installations, as there
should always be some activity on a system, by that is meant activity that
produces new WAL records, hence a checkpoints or a WAL segment switch after
a timeout (if archive\_timeout is set), would still have resulted in an
operation to happen.

The main issue here are embedded systems, where Postgres runs for ages
without intervention. For example an instance managing some internal
facility of a company very likely faces a downspike of activity on weekends,
because nobody is a robot and bodies need rest. Useless checkpoints being
generated actually can result in more WAL segments created. And while storing
those segments is not really a problem if they are compressed as the remaining
empty part is filled with zeros, installations that do not compress them
need some extra time to recover those segments in case of a crash, and that's
even more painful for developments that have a spiky WAL activity.

This has resulted in a couple of bug reports and misunderstandings over
the last couple of years on the community mailing lists like
[this thread](https://www.postgresql.org/message-id/20151016203031.3019.72930@wrigleys.postgresql.org).

So in order to fix this problem has been designed a system allowing
to mark a WAL record as "important" or not regarding the activity it
creates. There has been much debate about the wording of this concept,
named at some point as well "progress", debate going on for perhaps more
than a hundred of emails across many threads. There is also a set of
routines that can be used to fetch the last important WAL position that
can be used for more checks and do more fancy decision-making.

With this facility in place, records related to archive\_timeout, understand
here WAL segment switch, and standby snapshots (WAL-logging of exclusive locks
and running transactions for hor standby nodes) are considered as
unimportant WAL activity to decide if a checkpoint should be executed or not.
Once those records are marked as such, deciding if a checkpoint should be
skipped or not is just a matter of comparing the WAL position of the last
checkpoint record with the last important WAL position. If they match, no
checkpoint need to happen. And then embedded systems are happy.
