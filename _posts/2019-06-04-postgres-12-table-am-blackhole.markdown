---
author: Michael Paquier
lastmod: 2019-06-04
date: 2019-06-04 05:16:34+00:00
layout: post
type: post
slug: postgres-12-table-am-blackhole
title: 'Postgres 12 highlight - Table Access Methods and blackholes'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 12
- table
- data
- blackhole

---

Postgres is very nice when it comes to extending with custom plugins, with
many set of facilities available, like:

  * [Decoder plugins](https://www.postgresql.org/docs/devel/logicaldecoding-explanation.html)
  * [Extensions](https://www.postgresql.org/docs/devel/extend-pgxs.html)
  * [Background workers](https://www.postgresql.org/docs/devel/bgworker.html)
  * [Index access methods](https://www.postgresql.org/docs/devel/indexam.html)
  * Hooks
  * Custom function, aggregate, data types, etc.

After a heavy refactoring of the code, Postgres 12 ships with a basic
infrastructure for
[table access methods](https://www.postgresql.org/docs/devel/tableam.html)
which allows to customize how table data is stored and accessed.  By default,
all tables in PostgreSQL use the historical heap, which works on a page-based
method of 8kB present in segment files of 1GB (default sizes), with full
tuple versions stored.  This means, in simple words, that even updating one
attribute of a tuple requires storing a full new version.  This makes the
work related to vacuum and autovacuum more costly as well.  Well, the goal
of this post is not to discuss about that, and there is
[documentation](https://www.postgresql.org/docs/devel/storage-page-layout.html)
on the matter.  So please feel free to refer to it.

Table access methods are really cool, because they basically allow to plugin
directly into Postgres a kind of equivalent to MySQL storage engines, making
it possible to implement things like columnar storage, which is something
where heap is weak at.  It is possible to roughly classify what is possible
to do into two categories:

  * Access method going through the storage manager of Postgres, which makes
  use of the existing shared buffer layer, with the exiting paging format.
  This has two advantages: backups and checksums are normally, and mostly,
  automatically supported.
  * Access method not going through Postgres, which has the advantage to not
  rely on Postgres shared buffers (page format can be a problem as well),
  making it possible to rely fully on the OS cache.  Note that it is then
  up to you to add support for checksumming, backups, and such.

Access methods could make a comparison with foreign data wrappers, but the
reliability is much different, one big point being that they are fully
transactional with the backend they work with, which is usually a big deal
for applications, and have transparent DDL and command support (if
implemented in the AM).

Last week at PGCon in Ottawa, there were two talks on the matter by:

  * [Andres Freund](https://www.pgcon.org/2019/schedule/events/1374.en.html)
  * [Pankaj Kapoor](https://www.pgcon.org/2019/schedule/events/1321.en.html)

The presentation slides are attached directly on those links, and these will
give you more details about the feature.  Note that there have been recent
discussions with new AMs, like zheap or zstore (names beginning by 'z'
because that's a cool letter to use in a name).  It is also limiting to not
have pluggable WAL (generic WAL can be used but that's limited and not
performance-wise), but this problem is rather hard to tackle as contrary
to table AMs, WAL require registering callbacks out of system catalogs, and
resource manager IDs (understand a category of WAL records) need to have hard
values.  Note that TIDs may also become of problem depending on the AM.

There is a large set of callbacks defining what a table AM is (42 as of when
writing this post), and the interface may change in the future, still this
version provides a very nice first cut.

On the flight back from Ottawa, I took a couple of hours to look at this
set of callbacks and implemented a template for table access methods called
[blackhole\_am](https://github.com/michaelpq/pg_plugins/tree/master/blackhole_am).
This AM is mainly here as a base for creating a new plugin, and it has the
property to send to the void any data on a table making use of it.  Note that
creating a table access method requires
[CREATE ACCESS METHOD](https://www.postgresql.org/docs/devel/sql-create-access-method.html),
which is embedded directly in an extension here:

    =# CREATE EXTENSION blackhole_am;
    CREATE EXTENSION
    =# \dx+ blackhole_am
       Objects in extension "blackhole_am"
               Object description
    -----------------------------------------
     access method blackhole_am
     function blackhole_am_handler(internal)
    (2 rows)

Then a table can be defined to use it, throwing away any data:

    =# CREATE TABLE blackhole_tab (id int) USING blackhole_am;
    CREATE TABLE
    =# INSERT INTO blackhole_tab VALUES (generate_series(1,100));
    INSERT 0 100
    =# SELECT * FROM blackhole_tab;
     id
    ----
    (0 rows)

Note that there is a parameter controlling the default table access
method, called default\_table\_access\_method, enforcing the value of
the USING clause to it.  "heap" is the default.  This feature opens a
lot of doors and possibilities, so have fun with it.
