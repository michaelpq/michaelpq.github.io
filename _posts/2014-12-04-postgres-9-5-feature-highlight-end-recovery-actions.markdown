---
author: Michael Paquier
lastmod: 2014-12-04
date: 2014-12-04 13:37:22+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-end-recovery-actions
title: 'Postgres 9.5 feature highlight - standby actions at the end of recovery'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.5
- replication
- wal

---

PostgreSQL offers many ways to define how a node reaches the end of recovery
with many parameters related to [recovery target]
(https://www.postgresql.org/docs/devel/static/recovery-target-settings.html),
like a timestamp, a transaction ID, a target name and recovery timeline,
using recovery\_target\_timeline. A parameter called pause\_at\_recovery\_target
that exists since 9.1 allows as well to put a standby in pause when the
recovery target is reached. The upcoming release 9.5 has made some
improvements in this area with the following commit:

    commit: aedccb1f6fef988af1d1a25b78151f3773954b4c
    author: Simon Riggs <simon@2ndQuadrant.com>
    date: Tue, 25 Nov 2014 20:13:30 +0000
    action_at_recovery_target recovery config option

    action_at_recovery_target = pause | promote | shutdown

    Petr Jelinek

    Reviewed by Muhammad Asif Naeem, Fujji Masao and
    Simon Riggs

Its use is rather simple, when a standby has hot\_standby enabled in
postgresql.conf, meaning that it is able to execute read queries while
being in recovery, it is possible to perform the set of actions defined
above using recovery\_target\_action in recovery.conf. Note that the
former parameter name was action\_at\_recovery\_target, it has been
renamed to recovery\_target\_action afterwards in commit [b8e33a8]
(https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=b8e33a):

  * pause, acting the same as when pause\_at\_recovery\_target is enabled
  to have the standby pause any replay actions so as it is possible to
  check in which state it is once the recovery target has been reached.
  Note as well that the recovery replay can be resumed using
  pg\_xlog\_replay\_resume().
  * promote, to perform automatically a promotion of the node and have
  it just to the next timeline, making it available for write queries
  as well. This is the same as when pause\_at\_recovery\_target or
  recovery\_target\_action are not used, or when only
  pause\_at\_recovery\_target is used and set to false.
  * shutdown, to simply shutdown the standby once target is reached.
  This is the real new addition that this feature brings in because this
  can be used to make a standby instance immediately ready for use after
  it has finished its recovery. Note that in this case the node will
  also need to re-apply all the WAL since last checkpoint, so there is
  some cost in this mode. Moreover, recovery.conf is not renamed to
  recovery.done automatically. So this setting need to be removed
  in recovery.conf (simply removing the file is not something to
  recommend as server would miss post-end-recovery sanity checks).

Now let's put in recovery a standby that has the following parameters
in recovery.conf:

    recovery_target_time = '2014-12-04 22:21:52.922328'
    recovery_target_action = 'shutdown'
    restore_command = 'cp -i /path/to/archive/%f %p'

When a recovery target is reached (timestamp, XID, name), the following
logs will show up if shutdown is set up for the end of recovery.

    LOG:  recovery stopping before commit of transaction 1004, time 2014-12-04 22:22:19.554052+09
    LOG:  shutdown at recovery target
    LOG:  shutting down 

Also, note that both parameters cannot be used at the same time. An
error being returned by server as follows as pause\_at\_recovery\_target
is logically deprecated (note that this old parameter may be removed
in a couple of months altogether).

    FATAL:  cannot set both "pause_at_recovery_target" and
            "recovery_target_action" recovery parameters
    HINT:  The "pause_at_recovery_target" is deprecated.

That's nice stuff, useful for the control of nodes to-be-promoted when
checking for their data consistency.
