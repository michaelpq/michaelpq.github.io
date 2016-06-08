---
author: Michael Paquier
OBlastmod: 2016-06-08
date: 2016-06-08 07:30:55+00:00
layout: post
type: post
slug: postgres-9-6-feature-highlight-wait-events
title: 'Postgres 9.6 feature highlight: Tracking of wait events'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- 9.6
- feature
- highlight
- activity
- statistics
- wait
- event
- pg_stat_activity
- lock
- buffer
- pin
- catalog
- light-weight
- heavy

---

PostgreSQL 9.6 is introducing a new in-core infrastructure to help in the
tracking of wait events for backend processes which has been introduced
by this commit mainly and some other subcommits:

    commit: 53be0b1add7064ca5db3cd884302dfc3268d884e
    author: Robert Haas <rhaas@postgresql.org>
    date: Thu, 10 Mar 2016 12:44:09 -0500
    Provide much better wait information in pg_stat_activity.

    When a process is waiting for a heavyweight lock, we will now indicate
    the type of heavyweight lock for which it is waiting.  Also, you can
    now see when a process is waiting for a lightweight lock - in which
    case we will indicate the individual lock name or the tranche, as
    appropriate - or for a buffer pin.

    Amit Kapila, Ildus Kurbangaliev, reviewed by me.  Lots of helpful
    discussion and suggestions by many others, including Alexander
    Korotkov, Vladimir Borodin, and many others.

This commit has added two columns to
[pg\_stat\_activity](https://www.postgresql.org/docs/devel/static/monitoring-stats.html#PG-STAT-ACTIVITY-VIEW)
which gives a SQL representation of the active backend processes reporting
to the statistics collector (background workers can similarly do that by
using pgstat\_report\_activity): wait\_event\_type which reports the type
of event a backend is waiting for, and wait\_event which is the name of
the event being waiting for.

There are a couple of categories to be aware of regarding wait\_event\_type:

  * LWLockNamed, the backend is waiting for a light-weight lock, which happens
  when a backend calls LWLockAcquire() to acquire such a lock which are
  designed to control access to shared memory structures for example.
  * LWLockTranche, similar to the previous category, except that those are
  related to locks that have a predefined position in the set of light-weight
  lock array.
  * Lock, which is a heavy-weight lock, and reported for code paths called
  LockAcquire or LockAcquireExtended mainly, and are used most of the time
  for objects that are present at SQL level like relations for example.
  * BufferPin, the backend is waiting to acquire a pin on a shared buffer.

Those things are proving to be useful for debugging applications in details
that were not available up to now. For example with the following backend
that drops a table in a transaction prepared with 2PC:

    =# CREATE TABLE aa ();
    CREATE TABLE
    =# BEGIN;
    BEGIN
    =# DROP TABLE aa;
    DROP TABLE
    =# PREPARE TRANSACTION 'tt';
    PREPARE TRANSACTION

If a second transaction tries to read from this table it would just be
stuck on a relation lock, and those new fields allow this tracking in
a very handful way:

    =# SELECT query, wait_event_type, wait_event FROM pg_stat_activity
       WHERE wait_event IS NOT NULL;
           query       | wait_event_type | wait_event
    -------------------+-----------------+------------
     SELECT * FROM aa; | Lock            | relation
    (1 row)

And the information provided by those new fields find more usages when
tracking buffer or lock activity, which depend heavily on what a given
application is having a point of contention on.

Note that the wait event facility that has been implemented in the statistics
collector is designed to be light-weight and highly flexible, so as new
event types could be tracked on the top. One thing that is for example missing
in 9.6 is the tracking of waiting latches (backends calling WaitLatch() for
example), for which I have written out a patch submitted in the queue for
integration in 9.7. In this case the main use case where this would be
useful is the tracking of backends being stuck because of synchronous
replication.
