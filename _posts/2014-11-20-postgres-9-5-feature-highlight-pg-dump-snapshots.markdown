---
author: Michael Paquier
lastmod: 2014-11-20
date: 2014-11-20 14:12:26+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-pg-dump-snapshots
title: 'Postgres 9.5 feature highlight: pg_dump and external snapshots'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- highlight
- 9.5
- feature
- dump
- data
- pg_dump
- external
- consistent
- snapshot
- logical
- replication
- slot

---

A couple of days ago the following feature related to [pg\_dump]
(http://www.postgresql.org/docs/devel/static/app-pgdump.html) has been
committed and will be in Postgres 9.5:

    commit: be1cc8f46f57a04e69d9e4dd268d34da885fe6eb
    author: Simon Riggs <simon@2ndQuadrant.com>
    date: Mon, 17 Nov 2014 22:15:07 +0000
    Add pg_dump --snapshot option

    Allows pg_dump to use a snapshot previously defined by a concurrent
    session that has either used pg_export_snapshot() or obtained a
    snapshot when creating a logical slot. When this option is used with
    parallel pg_dump, the snapshot defined by this option is used and no
    new snapshot is taken.

    Simon Riggs and Michael Paquier

First, let's talk briefly about [exported snapshots]
(http://www.postgresql.org/docs/devel/static/functions-admin.html#FUNCTIONS-SNAPSHOT-SYNCHRONIZATION),
a feature that has been introduced in PostgreSQL 9.2. With it, it is possible
to export a snapshot from a first session with pg\_export\_snapshot, and
by reusing this snapshot in transactions of other sessions all the
transactions can share exactly the same state image of the database. When
using this feature something like that needs to be done for the first session
exporting the snapshot:

    =# BEGIN;
    BEGIN
    =# SELECT pg_export_snapshot();
     pg_export_snapshot
    --------------------
     000003F1-1
    (1 row)

Then other sessions in parallel can use SET TRANSACTION SNAPSHOT to import
back the snapshot and share the same database view as all the other transactions
using this snapshot (be it the transaction exporting the snapshot or the other
sessions that already imported it).

    =# BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
    BEGIN
    =# SET TRANSACTION SNAPSHOT '000003F1-1';
    SET
    =# -- Do stuff
    [...]
    =# COMMIT;
    COMMIT

Note that the transaction that exported the snapshot needs to remain active
as long as the other sessions have not consumed it with SET TRANSACTION.
This snapshot export and import dance is actually used by pg\_dump since 9.3
for parallel dumps to make consistent the dump acquisition across the threads,
whose number is defined by --jobs, doing the work.

Now, this commit adding the option --snapshot is simply what a transaction
importing a snapshot does: caller can export a snapshot within the transaction
of a session and then re-use it with pg\_dump to take an image of a given
database consistent with the previous session transaction. Well, doing only
that is not that useful in itself. The fun begins actually by knowing that
there is a different situation where a caller can get back a snapshot name,
and this situation exists since 9.4 because it is the moment a [logical slot]
(http://www.postgresql.org/docs/devel/static/logicaldecoding-explanation.html#AEN66595).
is created through a replication connection.

    $ psql "replication=database dbname=dbname"
    [...]
    =# CREATE_REPLICATION_SLOT foo3 LOGICAL test_decoding;
     slot_name | consistent_point | snapshot_name | output_plugin
    -----------+------------------+---------------+---------------
     foo       | 0/16ED738        | 000003E9-1    | test_decoding
    (1 row)

See "000003E9-1" in the field snapshot\_name? That is the target. Note a
couple of things as well at this point:

  * The creation of a physical slot does not return back a snapshot.
  * The creation of a logical slot using pg\_create\_logical\_replication\_slot
  with a normal connection (let's say non-replication) does not give
  back a snapshot name.
  * The snapshot is alive as long as the replication connection is
  kept. That is different of pg\_export\_snapshot called in the context
  of a non-replication connection where the snapshot remains alive
  as long as the transaction that called it is not committed (or aborted).

This is where this feature takes all its sense: it is possible to get an
image of the database at the *moment* the slot has been created, or putting
it in other words *before* any changes in the replication slot have been
consumed, something aimed to be extremely useful for replication solutions
or cases like online migration/upgrade of databases because it means
that the dump can be used as a base image on which changes could be replayed
without data lost. Then, the dump can simply be done like that:

    pg_dump --snapshot 000003E9-1

When doing a parallel dump with a snapshot name, the snapshot specified
is used for all the jobs and is not enforced by the first worker as it would
be the case when a snapshot name is not specified, or when pg\_dump would work
in 9.3 and 9.4. Note as well that it is possible to use a newer version of
pg\_dump on older servers so it is fine to take a dump with an exported
snapshot with 9.5's pg\_dump from a 9.4 instance of Postgres, meaning that
the door of a live upgrade solution of a single database is not closed
(combined with the fact that a client application consuming changes from
a logical replication slot can behave as a synchronous standby).
