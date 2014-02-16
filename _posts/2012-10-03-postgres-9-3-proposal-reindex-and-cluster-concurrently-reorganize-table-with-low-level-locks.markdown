---
author: Michael Paquier
comments: true
lastmod: 2012-10-03
date: 2012-10-03 02:30:33+00:00
layout: post
type: post
slug: postgres-9-3-proposal-reindex-and-cluster-concurrently-reorganize-table-with-low-level-locks
title: 'Postgres 9.3 proposal: REINDEX and CLUSTER CONCURRENTLY, reorganize table
  with low-level locks?'
wordpress_id: 1330
categories:
- PostgreSQL-2
tags:
- '9.3'
- cluster
- concurrently
- database
- free
- index
- open source
- postgres
- postgresql
- proposal
- reindex
- reorganize
- version
---

Last week, I had an interesting [discussion in the Postgres hackers mailing list](http://archives.postgresql.org/pgsql-hackers/2012-09/msg00746.php) about integrating pg_reorg features (possibility to reorganize a table without locks on it) directly into postgres core. Community strongly suggested that pg_reorg cannot be integrated as-is in the contribution modules of postgres core, and instead postgres should provide native ways to reorganize a table without taking heavy locks. This means that a table could be reindexed or clustered, and at the same time read and writes operations could still happen in parallel. What is particularly useful when an index is broken in a production database, as you could keep your table free of access for the other sessions running while the table is reorganized.

So, the following suggestions have been made:
	
  * Implementation of CLUSTER CONCURRENTLY	
  * Implementation of REINDEX CONCURRENTLY
  * ALTER TABLE CONCURRENTLY
  * Extend autovacuum to perform REINDEX and CLUSTER in parallel automatically

ALTER TABLE, CLUSTER and REINDEX share a common thing: they need high-level locks to be performed. So there is a risk that the table being manipulated by one of those operations could not be accessible for a long time, especially of the table is huge. The locks taken would block read and/or write operations for the other sessions, what is not acceptable for production environment if a critical table is touched.

Working on ALTER TABLE might be a huge piece of work, CLUSTER and REINDEX look more accessible. So I took some week-end spare time while a typhoon was on Tokyo area to write some code and studied the case of REINDEX CONCURRENTLY. And I finished with a patch, yeah!

Here are more details about the feature proposed...
You can rebuild a table or an index concurrently with such commands:

    REINDEX INDEX ind CONCURRENTLY;
    REINDEX TABLE tab CONCURRENTLY;

REINDEX CONCURRENTLY has the following restrictions:

  * REINDEX [ DATABASE | SYSTEM ] cannot be run concurrently.
  * REINDEX CONCURRENTLY cannot run inside a transaction block.
  * Shared tables cannot be reindexed concurrently
  * indexes for exclusion constraints cannot be reindexed concurrently.
  * toast relations are reindexed non-concurrently when table reindex is done and that this table has toast relations

Here are more details about the algorithm used. Roughly, a secondary index is created in parallel of the first one, it is completed. Then the old and fresh indexes are switched. For a more complete description (the beginning of the process is similar to CREATE INDEX CONCURRENTLY):

  1. creation of a new index based on the same columns and restrictions as the index that is rebuilt (called here old index). This new index has as name $OLDINDEX_cct. So only a suffix _cct is added. It is marked as invalid and not ready
  2. Take session locks on old and new index(es), and the parent table to prevent unfortunate drops
  3. Commit and start a new transaction
  4. Wait until no running transactions could have the table open with the old list of indexes
  5. Build the new indexes. All the new indexes are marked as indisready
  6. Commit and start a new transaction
  7. Wait until no running transactions could have the table open with the old list of indexes
  8. Take a reference snapshot and validate the new indexes
  9. Wait for the old snapshots based on the reference snapshot
  10. mark the new indexes as indisvalid
  11. Commit and start a new transaction. At this point the old and new indexes are both valid
  12. Take a new reference snapshot and wait for the old snapshots to insure that old indexes are not corrupted,
  13. Mark the old indexes as invalid
  14. Swap new and old indexes, consisting here in switching their names.
  15. Old indexes are marked as invalid.
  16. Commit and start a new transaction
  17. Wait for transactions that might use the old indexes
  18. Old indexes are marked as not ready
  19. Commit and start a new transaction
  20. Drop the old indexes

This feature will be normally submitted for review to the PostgreSQL 9.3 commit fest. For the time being patch has been given to community.

Some technical details...
	
  * A new set of functions has been created in index.c to manage concurrent operations.	
  * Code is relying a maximum on existing index creation, building and validation functions for maintainability.
  * Documentation, as well as regression tests have been added in the first version of the patch.
  * Concurrent operations are longer, require additional CPU, IO and memory but they are lock free. The parent relation and indexes cannot be dropped during process.
  * If an error occurs during process, the table will finish with invalid indexes (marked with suffix _cct in their names). It is the responsability of the user to drop them.
  * If you are looking for the patch, have a look [here](http://archives.postgresql.org/pgsql-hackers/2012-10/msg00128.php).

Please note that those specification notes are based on the first version of the patch proposed, and are subject to change depending on the community and reviewers' feedback.

**Edit 2012/10/14**: A new version of the patch has been submitted with the following enhancements:
	
  * Support for toast relations to be reindexed concurrently as well as other indexes	
  * Correction of drop behavior for constraint indexes
  * Correction of bugs
  * Support for exclusion constraints, looks to work as far as tested

The patch has been submitted to pgsql-hackers in [this email](http://archives.postgresql.org/pgsql-hackers/2012-10/msg00726.php).
