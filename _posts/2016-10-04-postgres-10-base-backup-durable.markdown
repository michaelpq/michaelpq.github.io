---
author: Michael Paquier
lastmod: 2016-10-04
date: 2016-10-04 08:15:09+00:00
layout: post
type: post
slug: postgres-10-base-backup-durable
title: 'Postgres 10 highlight - pg_basebackup and data durability'
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
- fsync
- sync
- data
- durability
- flush
- power
- loss
- reliable
- consistent
- pg_basebackup
- pg_receivexlog

---

One of the work areas happening for Postgres 10 currently in development
is the problem related to data durability when using the in-core utilities
to take data dumps, base backups, or anything related to Postgres like
WAL segments. In short, the goal is for users to be sure that any data
taken from Postgres using the in-core tools is still present and consistent
on disk even if a power failure occurs once the binary writing and flushing
the data is done. A couple of days ago the following commit has landed in
the code tree to improve the situation for pg\_basebackup and pg\_receivexlog:

    commit: bc34223bc1e2c51dff2007b3d3bd492a09b5a491
    author: Peter Eisentraut <peter_e@gmx.net>
    date: Thu, 29 Sep 2016 12:00:00 -0400
    pg_basebackup pg_receivexlog: Issue fsync more carefully

    Several places weren't careful about fsyncing in the way.  See 1d4a0ab1
    and 606e0f98 for details about required fsyncs.

    This adds a couple of functions in src/common/ that have an equivalent
    in the backend: durable_rename(), fsync_parent_path()

    From: Michael Paquier

It may not sound that complicated, but the devil is in the details here. On
top of a refactoring to make some routines already used by initdb available
as well for other binaries, a close lookup has been necessary to determine
when data can be flushed to disk safely and how it should happen. Of course,
cases where for example a base backup is returned directly to stdout, there
is no way for pg\_basebackup to guarantee that the data will still be here,
so it is up to the caller to make sure that data is consistently on disk.

For example, one corner case is at the creation of a WAL segment which is
padded of 16MB of zeros at creation in a code path used by both pg\_basebackup
or pg\_receivexlog. In the event of a crash between the zero-padding and
the fsync() of the WAL segment created, it may be possible that the segment
is still here with a size of 16MB, in which case it is safer to issue an
additional fsync() when opening it.

Note that by default pg\_basebackup will flush the data when it thinks
it is necessary to do so, for both the tar and normal format. For people
caring more about about performance that data consistency, a new --nosync
option has been added to pg\_basebackup with this
[commit](http://git.postgresql.org/pg/commitdiff/6ed2d8584cc680a2d6898480de74a57cd96176b5).
to emulate the pre-10 behavior. Though it is very encouraged to not use
it except for test environments if you care about your data. This is not
present for pg\_receivexlog because in its case reliability is the priority,
and that would be quite confusing with the existing --synchronous option
anyway.

Future improvements are also aimed for pg\_dump, likely a patch will be
made for the next commit fest beginning in November for integration in
Postgres 10. As the infrastructure is in place, this should require less
efforts.
