---
author: Michael Paquier
comments: true
lastmod: 2013-12-25
date: 2013-12-25 07:43:49+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-delayed-standbys
title: 'Postgres 9.4 feature highlight: delayed standbys'
categories:
- PostgreSQL-2
tags:
- 9.4
- data
- delay
- deletion
- feature
- fix
- highlight
- late
- master
- mistake
- new
- postgres
- postgresql
- recovery
- replay
- slave
- standby
- time
- wal
---
Postgres 9.4 has added a new feature allowing to delay WAL replay on standbys
or even to delay recovery by a given amount of time. It has been introduced by
this commit.

    commit 36da3cfb457b77a55582f68208d815f11ac1399e
    Author: Simon Riggs
    Date: Thu Dec 12 10:53:20 2013 +0000
 
    Allow time delayed standbys and recovery
 
    Set min_recovery_apply_delay to force a delay in recovery apply for commit and
    restore point WAL records. Other records are replayed immediately. Delay is
    measured between WAL record time and local standby time.
     
    Robert Haas, Fabrizio de Royes Mello and Simon Riggs
    Detailed review by Mitsumasa Kondo

Even if this does not replace the backup and WAL archive you should have in
case of disaster, Postgres did not cover up to now the possibility to have a
slave replaying WALs behind a master with a certain delay, WAL are replayed
once they are available. This can actually save time from some stupid DROP
TABLE that would force to do a PITR to recover the data to the point previous
to data deletion. In this case the delay allowed between the master node and
its standby(s) is the one you give yourself to repair the mistake you might
have done.

This is controlled with a new recovery parameter called
recovery\_min\_apply\_delay. Note that it is a minimum amount of time, as
WAL will be replayed when at least the commit time on master has reached the
threshold time specified by this parameter. As the calculation is based on
the commit time of transaction that occurred on master and the local clock
of standby server, you should as well be aware that if the clocks if the
master and slave server are not synchronized correctly this delay would be
not exact. This has as well as consequence that the delay is not cumulative
in cascading replication, so all the slaves will have the same delay.

Different timezones on master and slave nodes might lead to incorrect
calculation as well, so it is important to have system settings consistent
with this parameter, or you might find yourself with a slave that replays
WAL files before (or later) it should.

This parameter is represented as an int32 and its default unit is ms, so
the maximum delay time allowed is roughly 2 billion milliseconds, or 25 days.

Now let's see how this works with 2 nodes listening ports 5432 and 5433
running on a local machine and the following simple script:

    #!/bin/bash
    psql -c "CREATE TABLE aa AS SELECT 1 AS a" > /dev/null 2>&1
    echo "Start time: " `date`
    while [ /bin/true ]; do
      TUPLE=`psql -A -t -p 5433 -c "select * from aa" 2> /dev/null`
      if [ $TUPLE -a $TUPLE == 1 ]; then
        echo "Finish time: " `date`
        exit 0
      fi
      sleep 1
    done

It simply consists in creating a new 1-column table with one single value
and it checks every second if the tuple is present on slave. In this case
psql -A and -t to make the results respectively unaligned and tuple-only.

Now, when the delay is set to 10s, running this script gives the following
result:

    $ ./script.bash
    Start time: Wed Dec 25 01:26:35 JST 2013
    Finish time: Wed Dec 25 01:26:45 JST 2013

Of course that worked.
