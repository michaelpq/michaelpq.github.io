---
author: Michael Paquier
lastmod: 2015-09-05
date: 2015-09-05 14:02:22+00:00
layout: post
type: post
slug: postgres-extension-retrieve-fs-info
title: 'Postgres extension to retrieve file system information'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- pg_plugins
- monitoring
- wal

---

The set of [file access functions]
(http://www.postgresql.org/docs/devel/static/functions-admin.html#FUNCTIONS-ADMIN-GENFILE)
already present in PostgreSQL offer no direct possibility to retrieve file
system information, giving for example no coverage of how a file system is
behaving while running a given PostgreSQL instance. Modern platforms offer
usually the Posix system call statvfs, that allows to retrieve this information.
However, there is no direct equivalent on Windows, making the chance to have
an in-core feature available depend on what are the equivalent things
available statvfs for Windows, which may become ugly because this would
require at quick glance the use of multiple low-level functions like for
example GetDiskFreeSpaceExW to get the amount of free space available in
a given path. At least that would be less elegant than calling simply
statvfs.

And actually, getting at least the amount of free space available at FS-level
can prove to be useful particularly when a data directory is divided into
many partitions, usually things being splitted as:

  * PGDATA itself
  * pg_xlog
  * other partitions for tablespaces

This way it is possible for example to send alerts to users depending on the
percentage of space used. PL/Python allows to do already such a thing by using
os.statvfs, however it feels a bit more elegant to be able to have an
equivalent using a C function. So, seeing nothing in the Postgres community
ecosystem, here is a newly-written extension called [pg\_statvfs]
(https://github.com/michaelpq/pg_plugins/tree/master/pg_statvfs) that is a
simple wrapper calling statvfs, returning to caller filesystem information
about a requested path. Like the other file access functions, the function
introduced by this extension has the following properties:

  * Only superusers can call it.
  * Absolute paths that are out of PGDATA and log\_directory are forbidden.
  * Relative paths begin at the root of PGDATA.

Hence, once the binaries are compiled and installed, activating the extension
is straight-forward for a given database:

    =# CREATE EXTENSION pg_statvfs;
    CREATE EXTENSION
    =# \dx pg_statvfs
                       List of installed extensions
        Name    | Version | Schema |            Description
    ------------+---------+--------+-----------------------------------
     pg_statvfs | 1.0     | public | Wrapper for system call statvfs()
    (1 row)
    =# \dx+ pg_statvfs
    Objects in extension "pg_statvfs"
        Object Description
    ---------------------------
     function pg_statvfs(text)
    (1 row)

Note that this function, pg\_statvfs, returns all the values of struct statvfs,
including the flags describing the mount options for the requested path
(content present as an array with text elements, is OS-dependent), the fragment
size, the block size, etc.

Then, using SQL, it is really cool to take advantage of this data, with for
example a query like that, giving information about the remaining free
space in pg\_xlog (one use case of this query being to monitor replication slot
bloat):

    =# SELECT pg_size_pretty(f_blocks * f_bsize) AS total_space,
              pg_size_pretty(f_bfree * f_bsize) AS free_space
       FROM pg_statvfs('pg_xlog');
      total_space | free_space
     -------------+------------
      4812 MB     | 3925 MB
     (1 row)

This extension is available in the repository [pg_plugins]
(https://github.com/michaelpq/pg_plugins) on github. Feel free to grab it
and have a look if you feel that's of some usage for your application.
