---
author: Michael Paquier
lastmod: 2019-01-17
date: 2019-01-17 07:25:09+00:00
layout: post
type: post
slug: postgres-12-vacuum-skip-locked
title: 'Postgres 12 highlight - SKIP_LOCKED for VACUUM and ANALYZE'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 12
- vacuum
- lock

---

The [following commit](https://git.postgresql.org/pg/commitdiff/803b1301e8c9aac478abeec62824a5d09664ffff)
has been merged into Postgres 12, adding a new option for VACUUM and
ANALYZE:

    commit: 803b1301e8c9aac478abeec62824a5d09664ffff
    author: Michael Paquier <michael@paquier.xyz>
    date: Thu, 4 Oct 2018 09:00:33 +0900
    Add option SKIP_LOCKED to VACUUM and ANALYZE

    When specified, this option allows VACUUM to skip the work on a relation
    if there is a conflicting lock on it when trying to open it at the
    beginning of its processing.

    Similarly to autovacuum, this comes with a couple of limitations while
    the relation is processed which can cause the process to still block:
    - when opening the relation indexes.
    - when acquiring row samples for table inheritance trees, partition trees
    or certain types of foreign tables, and that a lock is taken on some
    leaves of such trees.

    Author: Nathan Bossart
    Reviewed-by: Michael Paquier, Andres Freund, Masahiko Sawada
    Discussion: https://postgr.es/m/9EF7EBE4-720D-4CF1-9D0E-4403D7E92990@amazon.com
    Discussion: https://postgr.es/m/20171201160907.27110.74730@wrigleys.postgresql.org

Postgres 11 has extended VACUUM so as multiple relations can be specified
in a single query, processing each relation one at a time.  However if VACUUM
gets stuck on a relation which is locked for a reason or another for a long
time, it is up to the application layer which has triggered VACUUM to be careful
to look at that and unblock the situation.  SKIP\_LOCKED brings more control
regarding that by skipping immediately any relation that cannot be locked at
the beginning of VACUUM or ANALYZE processing, meaning that the processing will
finish on a timely manner at the cost of potentially doing nothing, which can
also be dangerous if a table keeps accumulating bloat and is not cleaned up.
As mentioned in the commit message, there are some limitations similar to
autovacuum:

  * Relation indexes may need to be locked, which would cause the processing
  to still block when working on them.
  * The list of relations part of a partition or inheritance tree to process
  is built at the beginning of VACUUM or ANALYZE.  If the parent table is
  locked, then none of its children are processed.  If one of the children
  is locked and that the parent is listed in VACUUM, then all members of the
  trees are processed except the child locked.  However a limitation comes
  in the middle of acquiring sample rows for trees, as ANALYZE would block
  if a lock is acquired on a child when acquiring row samples for statistics
  on the parent.

This option is only supported with the parenthesized grammar of those
commands, for example:

    =# VACUUM (SKIP_LOCKED) tab1, tab2;
    WARNING:  55P03: skipping vacuum of "tab1" --- lock not available
    LOCATION:  expand_vacuum_rel, vacuum.c:654
    VACUUM

And in this case the second table listed got locked.

On the way, note that more options have been added to
[vacuumdb](https://www.postgresql.org/docs/devel/app-vacuumdb.html) thanks
to [this commit](https://git.postgresql.org/pg/commitdiff/354e95d1f2122d20c1c5895eb3973cfb0e8d0cc2):

    commit: 354e95d1f2122d20c1c5895eb3973cfb0e8d0cc2
    author: Michael Paquier <michael@paquier.xyz>
    date: Tue, 8 Jan 2019 10:52:29 +0900
    Add --disable-page-skipping and --skip-locked to vacuumdb

    DISABLE_PAGE_SKIPPING is available since v9.6, and SKIP_LOCKED since
    v12.  They lacked equivalents for vacuumdb, so this closes the gap.

    Author: Nathan Bossart
    Reviewed-by: Michael Paquier, Masahiko Sawada
    Discussion: https://postgr.es/m/FFE5373C-E26A-495B-B5C8-911EC4A41C5E@amazon.com

So, combined with --table, it is possible to get the same mapping as
what VACUUM and ANALYZE provide, though DISABLE\_PAGE\_SKIPPING is
present since 9.6.  This feature is also added into Postgres 12.
