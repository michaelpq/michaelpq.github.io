---
author: Michael Paquier
lastmod: 2015-03-12
date: 2015-03-12 12:54:46+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-compression-fpw-wal
title: 'Postgres 9.5 feature highlight: Compression of full-page writes in WAL'
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
- wal
- recovery
- fpw
- page
- full-page
- write
- compression
- reduce
- synchronous

---

In Postgres, [full-page writes]
(http://www.postgresql.org/docs/devel/static/runtime-config-wal.html#RUNTIME-CONFIG-WAL-SETTINGS).
which are in short complete images of a page added in WAL after the first
modification of this page after a checkpoint, can be an origin of WAL
bloat for applications manipulating many relation pages. Note that
full-page writes are critical to ensure data consistency in case particularly
if a crash happens during a page write, making perhaps this page made of both
new and old data.

In Postgres 9.5, the following patch has landed to leverage this quantity of
"recovery journal" data, by adding the possibility to compress full-page writes
in WAL (full commit message is shortened for this post and can be found [here]
(http://git.postgresql.org/gitweb/?p=postgresql.git;a=commitdiff;h=57aa5b2bb11a4dbfdfc0f92370e0742ae5aa367b)):

    commit: 57aa5b2bb11a4dbfdfc0f92370e0742ae5aa367b
    author: Fujii Masao <fujii@postgresql.org>
    date: Wed, 11 Mar 2015 15:52:24 +0900
    Add GUC to enable compression of full page images stored in WAL.

    When newly-added GUC parameter, wal_compression, is on, the PostgreSQL server
    compresses a full page image written to WAL when full_page_writes is on or
    during a base backup. A compressed page image will be decompressed during WAL
    replay. Turning this parameter on can reduce the WAL volume without increasing
    the risk of unrecoverable data corruption, but at the cost of some extra CPU
    spent on the compression during WAL logging and on the decompression during
    WAL replay.

    [...]

    Rahila Syed and Michael Paquier, reviewed in various versions by myself,
    Andres Freund, Robert Haas, Abhijit Menon-Sen and many others.

As described in this message, a new GUC parameter, called wal\_compression
by default disabled to not impact existing users, can be used for this
purpose. The compression of full-write pages is done using PGLZ, that has been
moved to [libpgcommon](http://git.postgresql.org/gitweb/?p=postgresql.git;a=commitdiff;h=40bede5477bb5bce98ce9548841cb414634c26f7)
a couple of weeks back as the idea is to make it available particularly for
frontend utilities of the type [pg_xlogdump]
(http://www.postgresql.org/docs/devel/static/pgxlogdump.html) that decode
WAL. Be careful though that compression has a CPU cost, in exchange of
reducing the I/O caused by WAL written to disks, so this feature is really
for I/O bounded environment or for people who want to reduce their amount of
WAL on disk and have some CPU to spare on it. There are also a couple of
benefits that can show up when using this feature:

  * WAL replay can speed up, meaning that a node in recovery can recover
  *faster* (after a crash, after creating a fresh standby node or whatever)
  * As synchronous replication is very sensitive to WAL length particularly
  in presence of multiple backends that need to wait for WAL flush confirmation
  from a standby, the write/flush position that a standby reports can be sent
  faster because the standby recovers faster. Meaning that synchronous
  replication response gets faster as well.

Note as well that this parameter can be changed without restarting the server
just with a reload, or SIGHUP, and that it can be updated within a session,
so for example if a given application knows that a given query is going to
generate a bunch of full-page writes in WAL, wal\_compression can be disabled
temporarily on a Postgres instance that has it set as enabled. The contrary
is true as well.

Now let's have a look at what this feature can do with for example the two
following tables having close to 480MB of data, on a server with 1GB of
shared\_buffers, the first table contains very repetitive data, and the second
uses uuid data (see [pgcrypto]
(http://www.postgresql.org/docs/devel/static/pgcrypto.html) for more details):

    =# CREATE TABLE int_tab (id int);
    CREATE TABLE
    =# ALTER TABLE int_tab SET (FILLFACTOR = 50);
    ALTER TABLE
    -- 484MB of repetitive int data
    =# INSERT INTO int_tab SELECT 1 FROM generate_series(1,7000000);
    INSERT 0 7000000
    =# SELECT pg_size_pretty(pg_relation_size('int_tab'));
    pg_size_pretty
    ----------------
     484 MB
    (1 row)
    =# CREATE TABLE uuid_tab (id uuid);
    CREATE TABLE
    =# ALTER TABLE uuid_tab SET (FILLFACTOR = 50);
    ALTER TABLE
    -- 484MB of UUID data
    =# INSERT INTO uuid_tab SELECT gen_random_uuid() FROM generate_series(1, 5700000);
    INSERT 0 5700000
    =# SELECT pg_size_pretty(pg_relation_size('uuid_tab'));
    pg_size_pretty
    ----------------
    484 MB
    (1 row)

The fillfactor is set to 50%, and each table will be updated, generated
completely full page writes with a minimum hole size to maximize the effects
of compression.

Now that the data has been loaded, let's be sure that it is loaded in the
database buffers (not mandatory here, but being maniac costs nothing), and
the number of shared buffers of those relations can be fetched at the same
time (not exactly the same but it does not really matter to have such few
diffence of pages at this scale):

    =# SELECT pg_prewarm('uuid_tab');
     pg_prewarm
    ------------
          61957
    (1 row)
    =# SELECT pg_prewarm('int_tab');
     pg_prewarm
    ------------
          61947
    (1 row)

After issuing a checkpoint, let's see how this behaves with the following
UPDATE commands:

    UPDATE uuid_tab SET id = gen_random_uuid();
    UPDATE int_tab SET id = 2;

Before and after each command pg\_current\_xlog\_location() is used to get
the XLOG position to evaluate the amount of WAL generated. So, after running
that with wal\_compression enabled and disabled, combined with a [trick]
(/postgresql-2/postgres-calculate-cpu-usage-process/) to calculate CPU for
a single backend, I am getting the following results:

 Case                    | WAL generated | User CPU | System CPU
-------------------------|---------------|----------|-----------
UUID tab, compressed     |        633 MB | 30.64    | 1.89
UUID tab, not compressed |        727 MB | 17.05    | 0.51
int tab, compressed      |        545 MB | 20.90    | 0.68
int tab, not compressed  |        727 MB | 14.54    | 0.84

In short, WAL compression saves 27% for this integer table, and 13% with
the data largely incompressible!

Note as well that PGLZ is a CPU-eater, so one of the areas of improvements
would be to plug in another compression algorithm of the type lz4, or add
a hook in backend code to be able to compress full-page writes with something
that has a license not necessarily compatible with PostgreSQL preventing its
integration into core code. Another area would be to make this parameter
settable at relation-level, as it depends on how a schema is compressible.
In any case, that's great stuff.
