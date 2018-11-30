---
author: Michael Paquier
lastmod: 2018-11-30
date: 2018-11-30 04:50:22+00:00
layout: post
type: post
slug: 2018-11-30-postgres-12-dos-prevention
title: 'Postgres 12 highlight - DOS prevention'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 12
- lock
- connection

---

A couple of months ago a
[thread](https://www.postgresql.org/message-id/152512087100.19803.12733865831237526317@wrigleys.postgresql.org)
has begun on the PostgreSQL community mailing lists about a set of
problems where it is possible to lock down PostgreSQL from connections
just by running a set of queries with any user, having an open connection
to the cluster being enough to do a denial of service.

For example, in one session do the following by scanning pg\_stat\_activity
in a transaction with any user:

    BEGIN;
    SELECT count(*) FROM pg_stat_activity;

This has the particularity to take an access share lock on the system
catalog pg\_authid which is a critical catalog used for authentication.
And then, with a second session and the same user, do for example VACUUM
FULL on pg\_authid, like that:

    VACUUM FULL pg_authid;

This user is not an owner of the relation so VACUUM will fail.  However,
at this stage the second session will be stuck until the first session
commits as an attempt to take a lock on the relation will be done, and a
VACUUM FULL takes an exclusive lock, which prevents anything to read or
write it.  Hence, in this particular case, as pg\_authid is used for
authentication, then no new connections can be done to the instance until
the transaction of the first session has committed.

As the thread continued, more commands have been mentioned as having
the same kind of issues:

  * As mentioned above, VACUUM FULL is a pattern.  In this case, queuing
  for a lock on a relation for which an operation will fail should not
  happen.  This takes an exclusive lock on the relation.
  * TRUNCATE, for reasons similar to VACUUM FULL.
  * REINDEX on a database or a schema.

The first two cases have been fixed for PostgreSQL 12, with
[commit a556549 for VACUUM](https://git.postgresql.org/pg/commitdiff/a556549)
and [commit f841ceb for TRUNCATE](https://git.postgresql.org/pg/commitdiff/f841ceb).
Note that similar work has been done a couple of years ado with for example
[CLUSTER in commit cbe24a6](https://git.postgresql.org/pg/commitdiff/cbe24a6).
In all those cases, the root of the problem is to make sure that the user
has the right to take a lock on a relation before attempting it and locking
it, so this has basically required a bit of refactoring so as the code
involved makes use of RangeVarGetRelidExtended() which has a custom callback
to do the necessary ownership and/or permission checks beforehand.  All this
infrastructure is present in PostgreSQL for a couple of years, added via
[commit 2ad36c4](https://git.postgresql.org/pg/commitdiff/2ad36c4).  Still
getting the patches into the right shape has required some thoughts as
changes should remain backward-compatible (for example with VACUUM, a
non-authorized attempt does not result in an error, but in a warning),
and things got a bit trickier with the addition of partitioned tables from
Postgres 10.

The case of REINDEX, fixed by
[commit 661dd23](https://git.postgresql.org/pg/commitdiff/661dd23), is a
bit more exotic as the root issue is different.  A user can run REINDEX
SCHEMA/DATABASE on respectively a schema or a database if he is an owner
of it.  The interesting fact is that shared catalogs (like pg\_authid) would
be included in the list of what gets reindexed even if the user owning the
schema/database does not own those shared catalogs, causing a lock conflict.
In this case, the fix has been to tighten a bit REINDEX so as shared catalogs
don't get reindexed if the user is not its owner.  This patch found its way
to PostgreSQL 11 and above, and has required a behavior change.

Fixing all those issues would have not been possible thanks to a lot of
individuals, first Robert Haas, Alvaro Herrera and Noah Misch who worked on an
infrastructure to improve queue locking behavior a couple of years ago, and
then to several folks who have spent time arguing and reviewing the different
patches proposed for the three cases mentioned in this post: mainly Nathan
Bossart, Kyotaro Horiguchi and more.  If more commands can be improved in
this area, feel free to report them for example by referring to the
[bug report guidelines](https://www.postgresql.org/docs/current/bug-reporting.html#id-1.3.8.7).
And we will get that patched up and improved.
