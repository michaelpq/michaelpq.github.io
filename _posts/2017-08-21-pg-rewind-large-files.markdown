---
author: Michael Paquier
lastmod: 2017-08-21
date: 2017-08-21 06:16:22+00:00
layout: post
type: post
slug: pg-rewind-large-files
title: 'pg_rewind and large file handling'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- pg_rewind
- large
- gb
- handling
- file
- corruption
- data
- copy
- block
- wal

---

The last round of minor releases of PostgreSQL has been released on the
[10th of August](https://www.postgresql.org/about/news/1772/) with a couple
of security problem addressed and many more bugs.

One item of the
[release notes](https://www.postgresql.org/docs/9.6/static/release-9-6-4.html)
refers to pg\_rewind with the following issue:

    Fix pg_rewind to correctly handle files exceeding 2GB (Kuntal Ghosh,
    Michael Paquier)
    Ordinarily such files won't appear in PostgreSQL data directories, but
    they could be present in some cases.

First, all the discussion of how this bug has been addressed is present in
the following thread:
https://www.postgresql.org/message-id/CAGz5QC+8gbkz=Brp0TgoKNqHWTzonbPtPex80U0O6Uh_bevbaA@mail.gmail.com

And while the release notes just mention that pg\_rewind cannot handle
properly large files, there are cases where this can lead to real data
corruption when repurposing an old primary to be a standby for a promoted
instance.

The first report of the thread mentioned that large files could not be
handled, a problem that could be reproduced by creating for example a
file larger than 2GB. This is primarily caused by the fact that when
pg\_rewind works on a live source server, it creates a temporary table
on it to track the set of files that it needs to read data from, using
three bits of information:

  * The path to the file to read.
  * The begin position from where to read.
  * The length of the data to read.

The design of this table is fine in itself, what was not though is that
the begin position, being a 4-byte signed integer, missed the fact that
it could not work for files larger than 2GB, leading to the initial error
that could be seen from the bug report:

    unexpected result while sending file list: ERROR:  value "2148000000"
       is out of range for type integer
    CONTEXT:  COPY fetchchunks, line 2402, column begin: "2148000000"

Well, that's not nice. But it does not really make sense to copy large
empty files that are located in the data folder so we could filter the
files by their path name to determine if they are worth copying or not,
still in order to keep things in pg\_rewind simple this has been
discarded as a solution.

[Additional investigation](https://www.postgresql.org/message-id/CAB7nPqRzOrKxwscwSdydef8tEbDLAscXW7RFK9dtChrR9nB9tg@mail.gmail.com)
has actually proved that the problem was a bit worse than it initially
looked, primarily because of the fact that Postgres can be configured
with relation segment file to be larger than 2GB, something that can be
set at the configure phase using --with-segsize. Most of the distributions
or vendors using PostgreSQL likely rely on the default size value of 1GB,
which makes such builds protected from any data corruption. But if you
have been using a custom build of Postgres, and that pg\_rewind was part
of a failover flow, then you are much likely in trouble.

When rewinding an old primary, pg\_rewind first scans WAL records from
the point where WAL forked for a promoted standby, and looks for the
set of relation blocks that have have been changed by those records,
leading to a list of files names, with blocks to fetch from a given
position with a length of BLCKSZ (by default 8kB). But if you try to
fetch a relation block that has a begin position higher than actually
4GB, then what pg_rewind would do is trying to get an incorrect block
because of an overflow. So, there are two risks here:

  * Fetching a block that does not need to be fetched, which is basically
  harmless because it means as well that the promoted standby already has
  it right and that the rewound primary will get that right by replaying
  WAL from the promoted standby. This results in a pure waste of resources.
  * Not fetching a block that is needed, which is where corruption issues
  will happen.

Then, after the old primary is rewound, it can be reused as a new standby
for previously promoted node, in which case it would replay WAL up to a
point where it would think that it has reached consistency, but an incorrect
set of relation blocks fetched would make things go very badly. A simple test
case on the discussion thread has showed up the top of the iceberg with an
incorrect number of tuples fetched when reading a full table using relation
segment files of 16GB. But other nasty things would happen in this case,
like incorrect tuple references, etc.

Special thanks to Kuntal Ghosh for finding out this issue first, which was
fun to debug and fix.
