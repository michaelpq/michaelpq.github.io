---
author: Michael Paquier
lastmod: 2015-05-28
date: 2015-05-28 08:06:45+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-partial-segment-timeline
title: 'Postgres 9.5 feature highlight - Archiving of last segment on timeline after promotion'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- highlight
- feature
- 9.5
- archive
- wal
- partial
- debug
- current
- timeline
- segment

---

Postgres 9.5 is bringing a change in the way WAL is archived with the following
[commit](http://git.postgresql.org/gitweb/?p=postgresql.git;a=commitdiff;h=de768844):

    commit: de7688442f5aaa03da60416a6aa3474738718803
    author: Heikki Linnakangas <heikki.linnakangas@iki.fi>
    date: Fri, 8 May 2015 21:59:01 +0300
    At promotion, archive last segment from old timeline with .partial suffix.

    Previously, we would archive the possible-incomplete WAL segment with its
    normal filename, but that causes trouble if the server owning that timeline
    is still running, and tries to archive the same segment later. It's not nice
    for the standby to trip up the master's archival like that. And it's pretty
    confusing, anyway, to have an incomplete segment in the archive that's
    indistinguishable from a normal, complete segment.

    [...]

As mentioned in the commit log above, prior to 9.5, a standby would always try to
archive at promotion the last, partial WAL segment of the old timeline it was
recovering on. This is a behavior that has been present in Postgres for ages,
and there were no easy way to make a difference between a segment completely full
and one only partially completed.

The data of this last partial segment is available on the segment file of the
new timeline for the standby, but its name does not match the one of the old
timeline as it uses as prefix the new timeline standby has been promoted on,
and it contains data of the new timeline as well. Actually having it is useful
when recovering on the old timeline of the master.

Note as well that the pre-9.5 behavior can cause conflicts particularly in the
case where a master and its standby(s) point to the same archive location as
master would try to archive a complete segment once it is done with it, and
standby would archive a partial one with exactly the same name. Advanced users
are normally (hopefully) using archiving scripts more advanced than a single
copy command, so they may have some internal handling regarding such conflicts
enabling them to save both files and make a clear difference from which node
the segment has been archived, still it is an annoyance not to be able to
make the difference on server side.

Using a pair of nodes, like one master (listening to port 5432) and one standby
(listening to port 5433) streaming from the first one, and both of them having
the same archive\_command on the same server, here is actually how things happen.
First let's archive a couple of files on the master:

    =# SELECT pg_is_in_recovery();
     pg_is_in_recovery
    -------------------
     f
    (1 row)
    =# SHOW archive_command;
                 archive_command
     ----------------------------------------
	 cp -i %p /path/to/archive/%f
	(1 row)
    =# CREATE table aa AS SELECT generate_series(1,1000000);
    SELECT 1000000
    =# SELECT pg_current_xlog_location();
     pg_current_xlog_location
    --------------------------
     0/6D4E420
    (1 row)
    =# SELECT last_archived_wal FROM pg_stat_archiver;
        last_archived_wal
    --------------------------
     000000010000000000000005
    (1 row)

After standby promotion, the last, partial and final WAL segment of the
old timeline is archived by the standby with the suffix ".partial":

    $ pg_ctl promote -D /to/standby/pgdata/
    server promoting
    $ psql -At -p 5432 -c 'SELECT pg_switch_xlog()'
    0/6D4FE88
    $ ls /path/to/archive/
    000000010000000000000001
    000000010000000000000002
    000000010000000000000002.00000028.backup
    000000010000000000000003
    000000010000000000000004
    000000010000000000000005
    000000010000000000000006
    000000010000000000000006.partial
    00000002.history

The partial file, archived by the promoted standby, as well as the completed
segment, archived by the master are both present in the WAL archive path.

Finally, note that the server is not able to use a partial file suffixed with
.partial at recovery, so a manual operation is necessary to use it during the
recovery of a node by renaming it without this suffix ".partial".
