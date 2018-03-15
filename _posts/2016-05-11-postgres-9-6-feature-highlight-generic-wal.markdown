---
author: Michael Paquier
lastmod: 2016-05-11
date: 2016-05-11 06:55:34+00:00
layout: post
type: post
slug: postgres-9-6-feature-highlight-generic-wal-interface
title: 'Postgres 9.6 feature highlight - Generic WAL interface'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- 9.6
- feature
- highlight
- wal
- record
- generic
- general
- interface
- record
- slave
- replay
- page
- delta

---

One feature added in Postgres 9.6 is the [WAL generic interface](http://www.postgresql.org/docs/devel/static/generic-wal.html),
which is a base for more fancy things like [custom access methods](http://www.postgresql.org/docs/devel/static/sql-create-access-method.html).
Note that custom access methods are quite powerful in themselves as they allow
the development of for example custom index methods as external modules. The
generic WAL records have been added primarily as the infrastructure to provide
reliability to the custom access methods by allowing them to create WAL
records. This has been introduced by the following commit:

    commit: 65578341af1ae50e52e0f45e691ce88ad5a1b9b1
    author: Teodor Sigaev <teodor@sigaev.ru>
    date: Fri, 1 Apr 2016 12:21:48 +0300
    Add Generic WAL interface

    This interface is designed to give an access to WAL for extensions which
    could implement new access method, for example. Previously it was
    impossible because restoring from custom WAL would need to access system
    catalog to find a redo custom function. This patch suggests generic way
    to describe changes on page with standart layout.

    Bump XLOG_PAGE_MAGIC because of new record type.

    Author: Alexander Korotkov with a help of Petr Jelinek, Markus Nullmeier and
    minor editorization by my
    Reviewers: Petr Jelinek, Alvaro Herrera, Teodor Sigaev, Jim Nasby,
       Michael Paquier

Those records are designed with a central focus on reliability, meaning
that everything is focused on operating on the relation pages themselves,
which get replayed at recovery directly without the need of specific redo
routines. This has the advantage of making the whole facility robust and
really reliable, because each operation needed to make the replayed page
reach a consistent page is done internally by the generic WAL replay
routines. The WAL record generation is less performant than any of the
in-core access methods like say GIN or GiST, because more operations need
to be done at the end as general WAL routines like XLogInsert() and similar
things cannot be used by custom plugins, but the in-core design based on
reliability pays at the end for the end-user.

The generic WAL interface comes up with a couple of routines:

  * GenericXLogStart, to start the generation of a WAL record
  * GenericXLogRegisterBuffer, which returns the copy of a page to
  work on. Using that it is possible to register both a full page
  and the delta of an existing page.
  * GenericXLogFinish, to write the WAL record.
  * GenericXLogAbort, to cancel the WAL generation, providing an escape
  code path in case of failure handling.

Without knowing much about access methods, this can actually be used
by any custom plugin or extension to generate WAL records that work
at page level. For the sake of this post, I have hacked up a small
extension called [pg\_swap\_pages](https://github.com/michaelpq/pg_plugins/tree/master/pg_swap_pages)
that switches two pages of an existing relation and logs that in a WAL
record using two full page images. Take for example a cluster made of
one master and one standby with a simple table having more than two
pages:

    =# CREATE TABLE swapped_table (id int);
    CREATE TABLE
    =# INSERT INTO swapped_table VALUES (generate_series(1,1000));
    INSERT 0 1000

Using pageinspect it is possible to see that this table has indeed
tuples:

    =# CREATE EXTENSION pageinspect;
    CREATE EXTENSION
    =# SELECT lp, t_ctid
       FROM heap_page_items(get_raw_page('swapped_table', 0)) LIMIT 5;
     lp | t_ctid
    ----+--------
      1 | (0,1)
      2 | (0,2)
      3 | (0,3)
      4 | (0,4)
      5 | (0,5)
    (5 rows)
    =# SELECT lp, t_ctid
       FROM heap_page_items(get_raw_page('swapped_table', 1)) LIMIT 5;
     lp | t_ctid
    ----+--------
      1 | (1,1)
      2 | (1,2)
      3 | (1,3)
      4 | (1,4)
      5 | (1,5)
    (5 rows)

And now using the extension switching the pages things get messed up
on master, items from the first page going into the second page, and
vice-versa (look at t\_ctid for each tuple):

    =# CREATE EXTENSION pg_swap_pages;
    CREATE EXTENSION
    =# SELECT pg_swap_pages('swapped_table'::regclass, 0, 1);
     pg_swap_pages
    ---------------
     null
    (1 row)
    =# SELECT lp, t_ctid
       FROM heap_page_items(get_raw_page('swapped_table', 1)) LIMIT 3;
     lp | t_ctid
    ----+--------
      1 | (0,1)
      2 | (0,2)
      3 | (0,3)
    (3 rows)
    =# SELECT lp, t_ctid FROM heap_page_items(get_raw_page('swapped_table', 0)) LIMIT 3;
     lp | t_ctid
    ----+--------
      1 | (1,1)
      2 | (1,2)
      3 | (1,3)
    (3 rows)

And things are getting correctly messed up on the standby as well, meaning that
a generic WAL record has been correctly logged:

    =# SELECT pg_is_in_recovery();
     pg_is_in_recovery
    -------------------
     t
    (1 row)
    =# SELECT lp, t_ctid
       FROM heap_page_items(get_raw_page('swapped_table', 1)) LIMIT 3;
     lp | t_ctid
    ----+--------
      1 | (0,1)
      2 | (0,2)
      3 | (0,3)
    (3 rows)

pg\_xlogdump is showing as well the record by the way (output reformatted
for the needs of this post):

    rmgr: Generic
    len (rec/tot):      0/ 16382
    tx:          0
    lsn: 0/03051FF0
    prev 0/03051FB8
    desc: Generic
      blkref #0: rel 1663/16384/16385 blk 0 FPW
      blkref #1: rel 1663/16384/16385 blk 1 FPW

Other than this useless extension that would put your database in
an inconsistent state, Postgres itself has an extension making use of
the generic WAL interface in a far more advanced way with a contrib
module called [bloom](http://www.postgresql.org/docs/devel/static/bloom.html),
which is a module implementing a custom index method.

Hopefully this is going to give to the reader of this post new ideas,
because to be honest such new facilities open many new doors for
custom extension makers.
