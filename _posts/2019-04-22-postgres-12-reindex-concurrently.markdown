---
author: Michael Paquier
lastmod: 2019-04-22
date: 2019-04-22 6:52:09+00:00
layout: post
type: post
slug: postgres-12-reindex-concurrently
title: 'Postgres 12 highlight - REINDEX CONCURRENTLY'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 12
- reindex

---

A lot of work has been put into making Postgres 12 an excellent release
to come, and in some of the features introduced, there is one which found
its way into the tree and has been first proposed to community at the end
of 2012.  Here is the commit which has introduced it:

    commit: 5dc92b844e680c54a7ecd68de0ba53c949c3d605
    author: Peter Eisentraut <peter@eisentraut.org>
    date: Fri, 29 Mar 2019 08:25:20 +0100
    REINDEX CONCURRENTLY

    This adds the CONCURRENTLY option to the REINDEX command.  A REINDEX
    CONCURRENTLY on a specific index creates a new index (like CREATE
    INDEX CONCURRENTLY), then renames the old index away and the new index
    in place and adjusts the dependencies, and then drops the old
    index (like DROP INDEX CONCURRENTLY).  The REINDEX command also has
    the capability to run its other variants (TABLE, DATABASE) with the
    CONCURRENTLY option (but not SYSTEM).

    The reindexdb command gets the --concurrently option.

    Author: Michael Paquier, Andreas Karlsson, Peter Eisentraut
    Reviewed-by: Andres Freund, Fujii Masao, Jim Nasby, Sergei Kornilov
    Discussion: https://www.postgresql.org/message-id/flat/60052986-956b-4478-45ed-8bd119e9b9cf%402ndquadrant.com#74948a1044c56c5e817a5050f554ddee

As pointed out by the documentation,
[REINDEX](https://www.postgresql.org/docs/devel/sql-reindex.html) needs to
take an exclusive lock on the relation which is indexed, meaning that
for the whole duration of the operation, no queries can be run on it and
will wait for the REINDEX to finish.  Sometimes REINDEX can become very
handy in the event of an index corruption, or when in need to rebuild the
index because of extra bloat on it.  So the longer the operation takes,
the longer a production instance is not available, and that's bad for any
deployments so maintenance windows become mandatory.  There is a community
tool called pg\_reorg,
[which happens to be used by an organization](https://instagram-engineering.com/handling-growth-with-postgres-5-tips-from-instagram-d5d7e7ffdfcb)
called [Instagram](https://www.instagram.com/) aimed at reducing the impact
of a REINDEX at the cost of extra resources by using a trigger-based method
to replay tuple changes while an index is rebuilt in parallel of the
existing one.  Later this tool has been renamed to
[pg\_repack](https://github.com/reorg/pg_repack/).

REINDEX CONCURRENTLY is aimed at solving the same problems as the previous
tools mentioned by doing a REINDEX with a low-level lock (while being cheaper
than these tools!), meaning that read and write queries can happen while an
index is rebuilt, but the operation is longer, requires a couple of
transactions, and costs extra resources in the shape of more table scans.
Here is how an index is rebuilt in a concurrent fashion:

  * Create a new index in the catalogs which is a copycat of the one
  reindexed (with some exceptions, for example partition indexes don't
  have their inheritance dependency registered at creation, but at swap
  time).  This new, temporary is suffixed with "_ccnew".  Bref.
  * Build the new index.  This may take time, and there may be a lot of
  activity happening in parallel.
  * Let the new index catch up with the activity done during the build.
  * Rename the new index with the old index name, and switch (mostly!) all
  the dependencies of the old index to the new one.  The old index becomes
  invalid, and the new one valid.  This is called the swap phase.
  * Mark the old index as dead.
  * Drop the old index.

Each one of these steps needs one transaction.  When reindexing a table,
all the indexes to work on are gathered at once and each step is run
through all the indexes one-at-a-time.  One could roughly think of these
as a mix of CREATE INDEX CONCURRENTLY followed by DROP INDEX in a single
transaction, except that the constraint handling is automatic, and that
there is an extra step in the middle to make the switch from the old to
the new index fully transparent.

First things first.  I would like to point out that this patch would have
*never* found its way into the code tree without Andreas Karlsson, who has
sent a rebased version of my original patch at the beginning of 2017, for
a project I have been mainly working on from 2012 to 2014 with a couple of
independent pieces committed, giving up after losing motivation as there
was good vibes for getting that feature introduced in Postgres, but then
life moved on.  My original patch did a swap of the relfilenodes which
required an exclusive lock for a short amount of time, but that was not
really good as we want the concurrent reindex not allow read and write
queries in parallel of the rebuild at any moment.  Andreas has reworked
that part so as the new index gets renamed with the old index name, and
all the dependencies from the old to the new index are switched at the
same time to make the switch from the old to the new index transparent.
Then Peter Eisentraut has accepted to commit the patch.  So this feature
owes a *lot* to those two folks.  Since the feature has been first
proposed, it has happened that I have become myself a committer of Postgres
so I have been stepping up to fix issues related to this feature and
adjusting it for the upcoming release.

Note that if the REINDEX fails or is interrupted in the middle, then all
the indexes rebuilt are most likely in an invalid state, meaning that they
still consume space and that their definition is around, but they are
not used at all by the backend.  REINDEX CONCURRENTLY is designed so as
it is possible to drop invalid indexes.  There is a bit more about invalid
indexes to be aware about.  Here is first an invalid index:

    =# CREATE TABLE tab (a int);
    CREATE TABLE
    =# INSERT INTO tab VALUES (1),(1),(2);
    INSERT 0 3
    =# CREATE UNIQUE INDEX CONCURRENTLY tab_index on tab (a);
    ERROR:  23505: could not create unique index "tab_index"
    DETAIL:  Key (a)=(1) is duplicated.
    SCHEMA NAME:  public
    TABLE NAME:  tab
    CONSTRAINT NAME:  tab_index
    LOCATION:  comparetup_index_btree, tuplesort.c:4056
    =# \d tab
    Table "public.tab"
     Column |  Type   | Collation | Nullable | Default
    --------+---------+-----------+----------+---------
     a      | integer |           |          |
    Indexes:
        "tab_index" UNIQUE, btree (a) INVALID

Then, REINDEX TABLE CONCURRENTLY will *skip* invalid indexes because in
the event of successive and multiple failures then the number of indexes
would just ramp up, doubling at each run, causing a lot of bloat on the
follow-up reindex operations:

    =# REINDEX TABLE CONCURRENTLY tab;
    WARNING:  0A000: cannot reindex concurrently invalid index "public.tab_index", skipping
    LOCATION:  ReindexRelationConcurrently, indexcmds.c:2708
    NOTICE:  00000: table "tab" has no indexes
    LOCATION:  ReindexTable, indexcmds.c:2394
    REINDEX

It is however possible to reindex invalid indexes with just REINDEX INDEX
CONCURRENTLY:

=# DELETE FROM tab WHERE a = 1;
DELETE 2
=# REINDEX INDEX CONCURRENTLY tab_index;
REINDEX

Another thing to note is that CONCURRENTLY is not supported for catalog
tables as locks tend to be released before committing in catalogs so the
operation is unsafe, and indexes for exclusion constraints cannot be
processed.  Toast indexes are handled though.
