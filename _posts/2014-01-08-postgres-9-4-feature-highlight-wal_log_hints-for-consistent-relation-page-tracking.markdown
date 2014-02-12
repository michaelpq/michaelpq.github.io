---
author: Michael Paquier
comments: true
date: 2014-01-08 07:52:13+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-wal_log_hints-for-consistent-relation-page-tracking
title: 'Postgres 9.4 feature highlight: wal_log_hints for consistent relation page tracking in WAL'
wordpress_id: 2006
categories:
- PostgreSQL-2
tags:
- 9.4
- checksum
- database
- diff
- differential
- feature
- highlight
- hint bits
- information
- open source
- pg_rewind
- postgres
- postgresql
- transaction
- wal
---
In PostgreSQL terminology, hint bints are a page-level mechanism implemented to be able to guess the visibility status of a tuple directly at the page level (actually whether the tuple xmin or xmax is committed or aborted), without going though checks in pg\_clog and pg\_subtrans which are expensive. This is part of the field t\_infomask in HeapTupleHeaderData of htup\_details.h, a set of bits telling about more or less the tuple status on a page.

This has been introduced by the following commit, wal\_log\_hintbits being renamed to wal\_log\_hints after more discussions.

    commit 50e547096c4858a68abf09894667a542cc418315
    Author: Heikki Linnakangas
    Date: Fri Dec 13 16:26:14 2013 +0200
 
    Add GUC to enable WAL-logging of hint bits, even with checksums disabled.
 
    WAL records of hint bit updates is useful to tools that want to examine
    which pages have been modified. In particular, this is required to make
    the pg_rewind tool safe (without checksums).
 
    This can also be used to test how much extra WAL-logging would occur if
    you enabled checksums, without actually enabling them (which you can't
    currently do without re-initdb'ing).
 
    Sawada Masahiko, docs by Samrat Revagade. Reviewed by Dilip Kumar, with
    further changes by me.

This simple commit is really important for tools that do for example relation page analysis or play doing any kind of differential WAL operations to keep a track of all the pages that have been changed when a hint bit is modified, particularly by writing the entire content of each relation page to WAL during the first modification of that page after a checkpoint, even if hint bits are modified (hence the name of the parameter). This is something that is not done in Postgres 9.2 and older versions, and done in 9.3 only if checksums are enabled. Checksums however introduce a performance penalty at CPU level because the checksum of a page needs to be recalculated each time the page is modified, and is checked each time the page is read, so making checksums mandatory is troublesome for tools or systems that only need to keep a track of the hint bit information. PostgreSQL 9.3 offers only a trade with performance, but now 9.4 drops the barrier and makes the work easier.

Talking about a tool tracking modified pages, pg\_rewind, usable to reconnect a master to a cluster based on a promoted node, has been updated to reflect the introduction of this new parameter as well. Actually the project git repository now uses two branches: REL9\_3\_STABLE for the code that can be built on PostgreSQL 9.3.X, and master for the code that can be build based on PostgreSQL master branch. This is done to stick with a model close to Postgres itself and facilitate cross-version without any kind of if block based PG\_VERSION\_NUM that could make the code unreadable and harder to manage in the future. On REL9\_3\_STABLE, checksums are mandatory. For master (9.4 and above builds at the date of this post), either wal\_log\_hints or checksums are enough.

As this is disabled by default, be sure that you changed postgresql.conf accordingly.

    $ psql -c 'SHOW wal_log_hints'
     wal_log_hints
    ---------------
     on
    (1 row)

A new field in control data file has been added as well.

    $ pg_controldata | grep "wal_log_hints"
    Current wal_log_hints setting: on

The check in pg\_rewind on the value of wal\_log\_hints actually uses that.
