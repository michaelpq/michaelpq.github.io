---
author: Michael Paquier
lastmod: 2015-02-20
date: 2015-02-20 13:35:23+00:00
layout: post
type: post
slug: pg_dump-directory-format-compression
title: 'Short story with pg_dump, directory format and compression level'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- pg_dump
- compression

---

Not later than this week a bug regarding [pg\_dump]
(https://www.postgresql.org/docs/devel/static/app-pgdump.html) and compression
with zlib when dumping data has been reported [here]
(https://www.postgresql.org/message-id/20150217153446.2590.24945@wrigleys.postgresql.org).

The issue was that when calling -Fd, the compression level specified by -Z
was ignored, making the compressed dump having the same size for Z > 0. For
example with a simple table:

    =# CREATE TABLE dump_tab AS SELECT random() as a,
                                       random() as b
       FROM generate_series(1,10000000);
    SELECT 10000000

A dump keeps the same size whatever the compression level specified:

    $ for num in {0..4}; do pg_dump -Fd -t dump_tab -f \
        level_$num.dump -Z num ; done
    $ ls -l level_?.dump/????.dat.gz level_0.dump/????.dat
    -rw-r--r--  1 michael  staff  419999247 Feb 20 22:13 level_0.dump/2308.dat
    -rw-r--r--  1 michael  staff  195402899 Feb 20 22:13 level_1.dump/2308.dat.gz
    -rw-r--r--  1 michael  staff  195402899 Feb 20 22:14 level_2.dump/2308.dat.gz
    -rw-r--r--  1 michael  staff  195402899 Feb 20 22:15 level_3.dump/2308.dat.gz
    -rw-r--r--  1 michael  staff  195402899 Feb 20 22:16 level_4.dump/2308.dat.gz

After a couple of emails exchanged, it was found out that a call to gzopen()
missed the compression level: for example to do a compression of level 7, the
compression mode (without a strategy) needs to be something like "w7" or "wb7"
but the last digit was simply missing. An important thing to note is how quickly
the bug has been addressed, the issue being fixed within one day with this commit
(that will be available in the next series of minor releases 9.4.2, 9.3.7, etc.):

    commit: 0e7e355f27302b62af3e1add93853ccd45678443
    author: Tom Lane <tgl@sss.pgh.pa.us>
    date: Wed, 18 Feb 2015 11:43:00 -0500
    Fix failure to honor -Z compression level option in pg_dump -Fd.

    cfopen() and cfopen_write() failed to pass the compression level through
    to zlib, so that you always got the default compression level if you got
    any at all.

    In passing, also fix these and related functions so that the correct errno
    is reliably returned on failure; the original coding supposes that free()
    cannot change errno, which is untrue on at least some platforms.

    Per bug #12779 from Christoph Berg.  Back-patch to 9.1 where the faulty
    code was introduced.

And thanks to that, the dump sizes have a much better look (interesting to
see as well that a higher compression level is not synonym to less data
for this test case that has low repetitiveness):

    $ for num in {0..9}; do pg_dump -Fd -t dump_tab -f \
        level_$num.dump -Z num ; done
    $ ls -l level_?.dump/????.dat.gz level_0.dump/????.dat
    -rw-r--r--  1 michael  staff  419999247 Feb 20 22:24 level_0.dump/2308.dat
    -rw-r--r--  1 michael  staff  207503600 Feb 20 22:25 level_1.dump/2308.dat.gz
    -rw-r--r--  1 michael  staff  207065206 Feb 20 22:25 level_2.dump/2308.dat.gz
    -rw-r--r--  1 michael  staff  198538467 Feb 20 22:26 level_3.dump/2308.dat.gz
    -rw-r--r--  1 michael  staff  199498961 Feb 20 22:26 level_4.dump/2308.dat.gz
    -rw-r--r--  1 michael  staff  195780331 Feb 20 22:27 level_5.dump/2308.dat.gz
    -rw-r--r--  1 michael  staff  195402899 Feb 20 22:28 level_6.dump/2308.dat.gz
    -rw-r--r--  1 michael  staff  195046961 Feb 20 22:29 level_7.dump/2308.dat.gz
    -rw-r--r--  1 michael  staff  194413125 Feb 20 22:30 level_8.dump/2308.dat.gz
    -rw-r--r--  1 michael  staff  194413125 Feb 20 22:32 level_9.dump/2308.dat.gz

Nice community work to sort such things out very quickly.
