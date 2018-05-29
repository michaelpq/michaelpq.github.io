---
author: Michael Paquier
lastmod: 2015-02-13
date: 2015-02-13 06:27:13+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-pglz-compression-libpqcommon
title: 'Postgres 9.5 feature highlight - Compression with PGLZ in libpqcommon'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.5
- compression

---

As a preparation of an upcoming patch for full-page write compression in
[WAL](https://www.postgresql.org/docs/devel/static/wal.html), a patch has
been pushed this week to make PGLZ, the in-core compression algorithm
of PostgreSQL used for TOAST tables, more pluggable for plugins and frontend
applications, particularly pg\_xlogdump that needs to be able to decode a WAL
record using the XLOG reader facility even if blocks are compressed to be
able to reconstitute them. It makes as well sense to expose this algorithm
as PGLZ compressed data would not be limited only to the internal backend
usage of TOAST tables in a PostgreSQL instance, but as well to WAL data, be
it simple WAL archive or a WAL streaming flow. So, here is the commit:

    commit: 40bede5477bb5bce98ce9548841cb414634c26f7
    author: Fujii Masao <fujii@postgresql.org>
    date: Mon, 9 Feb 2015 15:15:24 +0900
    Move pg_lzcompress.c to src/common.

    The meta data of PGLZ symbolized by PGLZ_Header is removed, to make
    the compression and decompression code independent on the backend-only
    varlena facility. PGLZ_Header is being used to store some meta data
    related to the data being compressed like the raw length of the uncompressed
    record or some varlena-related data, making it unpluggable once PGLZ is
    stored in src/common as it contains some backend-only code paths with
    the management of varlena structures. The APIs of PGLZ are reworked
    at the same time to do only compression and decompression of buffers
    without the meta-data layer, simplifying its use for a more general usage.

    On-disk format is preserved as well, so there is no incompatibility with
    previous major versions of PostgreSQL for TOAST entries.

    Exposing compression and decompression APIs of pglz makes possible its
    use by extensions and contrib modules. Especially this commit is required
    for upcoming WAL compression feature so that the WAL reader facility can
    decompress the WAL data by using pglz_decompress.

    Michael Paquier, reviewed by me.

So, this makes PGLZ things available in the common library libpqcommon. Compared
to previous versions of PGLZ, its dependency on the varlena header has been
removed, and its compression and decompression routines have been reworked as
follows:

    extern int32 pglz_compress(const char *source, int32 slen, char *dest,
                               const PGLZ_Strategy *strategy);
    extern int32 pglz_decompress(const char *source, int32 slen, char *dest,
                                 int32 rawsize);

An error should occur, those routines would return -1. And in case of success,
are returned respectively the number of bytes compressed and decompressed,
in a manner close to lz4 (except that lz4 returns 0 in case of processing
error). Note: PGLZ is more CPU consuming than other compression algorithms.

Using those APIs, I implemented a simple extension able to do compression
and decompression of bytea, combined with a rough copy of the function
get\_raw\_page already present in the in-core contrib module [pageinspect]
(https://www.postgresql.org/docs/devel/static/pageinspect.html), with a new
option able to suppress the hole of a page, replacing with zeros the hole
of a page if it is wanted as this is more performant for compression. But, in
any case, any type of bytea data can be passed to the compression and
decompression functions.

    =# CREATE EXTENSION compression_test;
    CREATE EXTENSION
    =# \dx+ compression_test
      Objects in extension "compression_test"
                 Object Description
    --------------------------------------------
     function compress_data(bytea)
     function decompress_data(bytea,smallint)
     function get_raw_page(oid,integer,boolean)
    (3 rows)

Using this extension is rather simple, let's see for example with a sample
table that contains some data, like one tuple:

    =# CREATE TABLE compressed_tab (id int);
    CREATE TABLE
    =# INSERT INTO compressed_tab VALUES (1); -- 60 bytes on page without hole
    INSERT 0 1
    =# SELECT substring(page, 1, 20), hole_offset
       FROM get_raw_page('compressed_tab'::regclass, 0, false);
                     substring                  | hole_offset
    --------------------------------------------+-------------
     \x0000000060662413000000001c00e01f00200420 |          28
    (1 row)

The third argument of get\_raw\_page can be set to "false" to fetch a page
without hole, and to "true" to get a hole filled with zeros. The hole
offset is returned as well to be able to reconstitue the page. Now playing
with the compression and the decompression, here are some results:

    =# SELECT substring(compress_data(page), 1, 20), hole_offset
       FROM get_raw_page('compressed_tab'::regclass, 0, false);
                     substring                  | hole_offset
    --------------------------------------------+-------------
     \x0000000000606624130101081c00e01f00200402 |          28
    (1 row)
    =# SELECT substring(decompress_data(compress_data(page), 60::smallint), 1, 20),
              hole_offset
       FROM get_raw_page('compressed_tab'::regclass, 0, false);
                     substring                  | hole_offset
    --------------------------------------------+-------------
     \x0000000060662413000000001c00e01f00200420 |          28
    (1 row)

The data page gets down to 46 bytes from 60 bytes if compressed without hole
(this page contains not much data). Also, when requesting a decompression,
be sure to pass the raw length of the data that needs to be decompressed.

This extension is named [compress\_test]
(https://github.com/michaelpq/pg_plugins/tree/master/compress_test) and is
present in my [plugin repository](https://github.com/michaelpq/pg_plugins).
Note as well that the compression strategy used is PGLZ\_strategy\_always,
meaning that the data compression will always be attempted. Perhaps that is
useful, or not...
