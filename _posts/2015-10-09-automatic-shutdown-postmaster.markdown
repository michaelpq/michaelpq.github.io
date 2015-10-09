---
author: Michael Paquier
OBlastmod: 2015-10-09
date: 2015-10-09 07:15:53+00:00
layout: post
type: post
slug: automatic-shutdown-postmaster
title: 'Automatic shutdown of postmaster in case of incorrect lock file'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- commit
- postmaster
- pid
- file
- detection
- shutdown
- immediate
- recovery

---

Just to make people aware of it, the following commit has reached the
Postgres land a couple of days ago in all the active branches of the project,
down to 9.1:

    commit: 7e2a18a9161fee7e67642863f72b51d77d3e996f
    author: Tom Lane <tgl@sss.pgh.pa.us>
    date: Tue, 6 Oct 2015 17:15:52 -0400
    Perform an immediate shutdown if the postmaster.pid file is removed.

    The postmaster now checks every minute or so (worst case, at most two
    minutes) that postmaster.pid is still there and still contains its own PID.
    If not, it performs an immediate shutdown, as though it had received
    SIGQUIT.

    The original goal behind this change was to ensure that failed buildfarm
    runs would get fully cleaned up, even if the test scripts had left a
    postmaster running, which is not an infrequent occurrence.  When the
    buildfarm script removes a test postmaster's $PGDATA directory, its next
    check on postmaster.pid will fail and cause it to exit.  Previously, manual
    intervention was often needed to get rid of such orphaned postmasters,
    since they'd block new test postmasters from obtaining the expected socket
    address.

    However, by checking postmaster.pid and not something else, we can provide
    additional robustness: manual removal of postmaster.pid is a frequent DBA
    mistake, and now we can at least limit the damage that will ensue if a new
    postmaster is started while the old one is still alive.

    Back-patch to all supported branches, since we won't get the desired
    improvement in buildfarm reliability otherwise.

While the commit log is already very descriptive on the matter, the idea
is that if postmaster.pid has been replaced by something else or has simply
been removed, the postmaster will decide by itself to perform hara-kiri
and stop as if an immediate shutdown has been initiated. At next restart
this instance will then perform recovery actions. This can be faced under
this circumstance for example:

    $ rm $PGDATA/postmaster.pid
    [wait a bit]
    $ tail -n 4 $PGDATA/pg_log/some_log_file
    LOG:  performing immediate shutdown because data directory lock file is invalid
    LOG:  received immediate shutdown request

As the number of slow machines has rather increased in the [buildfarm]
(http://buildfarm.postgresql.org/cgi-bin/show_status.pl), this is aimed
at improving the robustness of the whole facility, the thread where this
patch came from mentioned as well that this can protect instances in some
special cases. See [here](http://www.postgresql.org/message-id/560AFA4D.1080305@joeconway.com)
for more details. If you face a similar situation once, you would surely
thank this commit aimed at preventing disasters of this kind. Note that
this is not included in this [week's release set]
(http://www.postgresql.org/message-id/CA+OCxoygxAhR16Sh4X1YSi5pSkLkYrPLWTknxTT84JM=P_Ma5A@mail.gmail.com),
and it will be in the next set.

Note as well that this was the last minor release for PostgreSQL 9.0
whish is now EOL, so for users still on this version, be sure to decide
as soon as possible an upgrade window to a newer major version.
