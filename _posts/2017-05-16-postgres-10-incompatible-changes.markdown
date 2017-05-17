---
author: Michael Paquier
lastmod: 2017-05-16
date: 2017-05-16 05:45:45+00:00
layout: post
type: post
slug: postgres-10-incompatible-changes
title: 'Postgres 10 highlight - Incompatible changes'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- 10
- feature
- highlight
- incompatible
- change
- modification
- option
- api

---

Postgres 10 will be released in a couple of months, with its beta 1 to be
out very soon, and for this release many small, incompatible changes have
been introduced during its development to help with long-term maintenance.
The full list of items is present in the
[release notes](https://www.postgresql.org/docs/devel/static/release-10.html),
and here are the changes that can have an impact on any applications relying
of what PostgreSQL has provided up to now.

Here are the changes related to the on-disk format of the data folders.

  * pg\_xlog has been renamed to pg\_wal. This has primarily consequences
  for any application handling with backup and restore, though the change
  to get the update right should be straight-forward.
  * pg\_clog has been renamed to pg\_xact.
  * Default value for log\_directory has been changed from "pg\_log" to
  "log". Most applications likely set this parameter to an absolute path
  anyway, hopefully pointing to a different partition. Or not.

The idea behind the first two items is to protect users always tempted
to perform a "rm -rf *log" in a data folder if the partition where data
is present gets full to free up some space. This would result in a
corrupted cluster.

Some commands have changes in option names, as well as default behavior
changes. Some commands are removed.

  * pg\_basebackup has changed the default value of --xlog-method to
  "stream", and "none" can be used to get the past behavior. It has been
  proven that users like being able to rely on self-contained, consistent
  backups. The option -x has been removed as well, being replaced by
  "-X fetch".
  * pg\_ctl not waits for all its subcommands to wait for completion by
  default. Note that if your application has relied on "start" mode leaving
  immediately when starting an instance to start recovery, pg\_ctl would
  wait also until the server has reached a consistent state. Better to be
  careful about that. "stop" has been always using the wait mode.
  * createlang and droplang are no more. RIP.

From the system-side of things, many things are piling up:

  * Cleartext password support has been removed, trying for example to
  create a role with UNENCRYPTED PASSWORD will return an error.
  * Any application using hash indexes need to reindex them after an
  upgrade. WAL-logging support for hash indexes has been added, and many
  enhauncements have been done as well. Since the introduction of streaming
  replication, hash indexes have not been that popular, but compared to
  btree hash indexes are an advantage when doing equal operations on columns
  with a high cardinality as less data pages need to be fetched to look
  for an index entry.
  * Support for version-0 functions has been removed. Most systems should
  be using version-1 anyway today.
  * Support for protocol version 1 is removed.

From the configuration side, there are three incompatible changes:

  * min\_parallel\_relation\_size is replaced by
  min\_parallel\_table\_scan\_size and min\_parallel\_index\_scan\_size
  to control better paralle queries.
  * password\_encryption has been changed from a boolean switch to an
  enum, with support for "md5" and "scram-sha-256". Note that this is in
  line with removal of cleartext passwords and addition of support for
  SCRAM-SHA-256 as a new hashing mechanism for passwords.
  * sql\_inheritance has been removed.
  
On top of that, another bigger change has happened with the removal of
the term "xlog" in system functions and binaries, replaced by "wal".

  * Functions like pg\_current\_xlog\_location are renamed to
  pg\_current\_wal\_lsn. So if you maintain a monitoring script be careful
  that it would break.
  * pg\_receivexlog is renamed to pg\_receivewal.
  * pg\_basebackup's --xlog-method is renamed to --wal-method.

Finally the version number has changed, switching from a 3-digit numbering
to a 2-digit numbering. By working on C extensions, things don't change much
except that PG\_VERSION\_NUM now has 6 digits. This is actually something
that may break applications relying on the old version string format fetched
for example by the SQL-level function version(). So be very careful about
that as well.
