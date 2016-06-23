---
author: Michael Paquier
lastmod: 2014-11-27
date: 2014-11-27 14:27:54+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-pageinspect-gin-indexes
title: 'Postgres 9.5 feature highlight - pageinspect extended for GIN indexes'
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
- gin
- index
- page
- raw
- compression
- content
- view
- pageinspect

---

The extension module [pageinspect]
(http://www.postgresql.org/docs/devel/static/pageinspect.html)
has been already dumped to version 1.3 in PostgreSQL 9.5 with the addition of
functions for [BRIN indexes]
(/postgresql-2/postgres-9-5-feature-highlight-brin-indexes/). A couple of
days back a new set of functions has been added for GIN indexes with this
commit.

    commit: 3a82bc6f8ab38be3ed095f1c86866900b145f0f6
    author: Heikki Linnakangas <heikki.linnakangas@iki.fi>
    date: Fri, 21 Nov 2014 11:46:50 +0200
    Add pageinspect functions for inspecting GIN indexes.

    Patch by me, Peter Geoghegan and Michael Paquier, reviewed by Amit Kapila.

This consists of a set of 3 functions that take as argument the raw content of
a relation page (fetched using get\_raw\_page):

  * gin\_page\_opaque\_info, able to fetch information about the flags located
  in the opaque area of a GIN page.
  * gin\_metapage\_info, able to translate information located in the meta page
  of a GIN index.
  * gin\_leafpage\_items, giving some information about the content of a GIN
  leaf page.

First let's create an index using the GIN operators of [pg\_trgm]
(http://www.postgresql.org/docs/devel/static/pgtrgm.html) on the book
"Les Miserables", English translation.

    =# CREATE EXTENSION pg_trgm;
    CREATE EXTENSION
    =# CREATE TABLE les_miserables (num serial, line text);
    CREATE TABLE
    =# COPY les_miserables (line) FROM '/path/to/les_miserables.txt';
    COPY 68116
    =# CREATE INDEX les_miserables_idx ON les_miserables
    USING gin (line gin_trgm_ops);
    CREATE INDEX

First, gin\_page\_opaque\_info provides information about the status of a page
(plus alpha like the right link page if any). Here is for example the status
of the meta page of the previous index and one of its leaf page.

    =# SELECT * FROM gin_page_opaque_info(get_raw_page('les_miserables_idx', 0));
     rightlink  | maxoff | flags
    ------------+--------+--------
     4294967295 |      0 | {meta}
    (1 row)
    =# SELECT * FROM gin_page_opaque_info(get_raw_page('les_miserables_idx', 3));
     rightlink | maxoff |         flags
    -----------+--------+------------------------
             5 |      0 | {data,leaf,compressed}
    (1 row)

Using gin\_metapage\_info, a direct visual of what is stored in GinMetaPageData
is available (refer mainly to gin_private.h for more details), failing if the
page accessed does not contain this information.

    =# SELECT * FROM gin_metapage_info(get_raw_page('les_miserables_idx', 0));
    -[ RECORD 1 ]----+-----------
    pending_head     | 4294967295
    pending_tail     | 4294967295
    tail_free_size   | 0
    n_pending_pages  | 0
    n_pending_tuples | 0
    n_total_pages    | 1032
    n_entry_pages    | 267
    n_data_pages     | 764
    n_entries        | 5791
    version          | 2
    =# SELECT * FROM gin_metapage_info(get_raw_page('les_miserables_idx', 1));
    ERROR:  22023: input page is not a GIN metapage
    DETAIL:  Flags 0000, expected 0008
    LOCATION:  gin_metapage_info, ginfuncs.c:62

Finally, gin\_leafpage\_items can be used to retrieve details about the items
stored in a leaf page (being either a posting tree or a posting list).

    =# SELECT first_tid, nbytes, tids[2] AS second_tid
       FROM gin_leafpage_items(get_raw_page('les_miserables_idx', 3)) LIMIT 4;
     first_tid | nbytes | second_tid
    -----------+--------+------------
     (149,94)  |    248 | (149,95)
     (154,11)  |    248 | (154,12)
     (158,62)  |    248 | (158,64)
     (163,14)  |    248 | (163,20)
    (4 rows)

This new set of functions improves the existing coverage of btree and BRIN.
Cool stuff for developers.
