---
author: Michael Paquier
lastmod: 2017-12-03
date: 2017-12-03 07:05:22+00:00
layout: post
type: post
slug: postgres-11-secondary-checkpoint
title: 'Postgres 11 highlight - Removal of secondary checkpoint'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 11
- wal
- checkpoint

---

It has been a long time since the last post. Today here is a post about the
following feature that will land in Postgres 11:

    commit: 4b0d28de06b28e57c540fca458e4853854fbeaf8
    author: Simon Riggs <simon@2ndQuadrant.com>
    date: Tue, 7 Nov 2017 12:56:30 -0500
    Remove secondary checkpoint

    Previously server reserved WAL for last two checkpoints,
    which used too much disk space for small servers.

    Bumps PG_CONTROL_VERSION

    Author: Simon Riggs
    Reviewed-by: Michael Paquier

Up to Postgres 10, PostgreSQL has been designed to maintain WAL segments
(Write-Ahead Log, an internal journal in the shape of binary data which
is used for recovering the instance up to a consistent point) worth two
checkpoints. This has as direct effect that past WAL segments are not
needed once two checkpoints have been completed, those getting either
removed or recycled (renamed). The interest behind keeping two checkpoints
worth of data is to get a fallback, so as if the last checkpoint record
cannot be found then the recovery falls back to the checkpoint record
prior that.

Note that on standbys, two checkpoints are not maintained, as only one
checkpoint worth of WAL segments is kept in the shape of restart points
created. The code path created both checkpoints and restart points is
very similar (look at xlog.c and checkpoint.c).

Falling back to the prior checkpoint can be actually a dangerous thing,
see for example this
[thread](https://www.postgresql.org/message-id/20160201235854.GO8743%40awork2.anarazel.de)
about the matter. And I have personally never faced a case where the last
checkpoint record was not readable and that it was necessary to fallback
to the prior checkpoint because the last checkpoint was not readable after
an instance crash (PostgreSQL being legendary stable as well, it is not like
one face crashes in production much anyway...).

So the commit above removes this prior checkpoint, which has a couple of
consequences:

  * Setting value of max\_wal\_size will reduce by roughly 33% the frequency
  of checkpoints happening, assuming that checkpoint\_target\_completion gets
  close to 1. The maximum amount of time to finish recovery after a crash
  would also take an additional amount of time. So you may want to actually
  reduce this setting if you are willing to keep a maximum recovery time
  up to a certain threshold.
  * Recovery or backup logics become more a bit more fragile. Well, that
  is not actually true as PostgreSQL 9.4 has introduced replication slots so
  as to make sure that a WAL segment needed for a self-contained backup or
  a client is still around. pg\_backbackup now also makes use by default
  of replication slots to avoid WAL segments to disappear in the middle of
  a backup because of a root node checkpoint recycling unneeded segments.

At the end, the change is proving to be beneficial for the end-user, because
the understanding of WAL segment recycling becomes way easier to explain
and also to people setting values like max\_wal\_size, as well as for
long-term maintenance, as the recovery code gets slightly simplified.
