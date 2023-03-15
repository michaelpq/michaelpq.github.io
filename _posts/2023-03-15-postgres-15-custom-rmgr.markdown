---
author: Michael Paquier
lastmod: 2023-03-15
date: 2023-03-15 10:22:22+00:00
layout: post
type: post
slug: postgres-15-custom-rmgr
title: 'Postgres 15 highlight - Custom WAL Resource Managers'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 15
- wal
- guc
- plugin

---

Postgres 15 has a [release note page](https://www.postgresql.org/docs/15/release-15.html)
full of items, and this commit is one of the fun parts from the point of
view of a hacker:

    commit: 5c279a6d350205cc98f91fb8e1d3e4442a6b25d1
    author: Jeff Davis <jdavis@postgresql.org>
    date: Wed, 6 Apr 2022 22:26:43 -0700
    Custom WAL Resource Managers.

    Allow extensions to specify a new custom resource manager (rmgr),
    which allows specialized WAL. This is meant to be used by a Table
    Access Method or Index Access Method.

    Prior to this commit, only Generic WAL was available, which offers
    support for recovery and physical replication but not logical
    replication.

    Reviewed-by: Julien Rouhaud, Bharath Rupireddy, Andres Freund
    Discussion: https://postgr.es/m/ed1fb2e22d15d3563ae0eb610f7b61bb15999c0a.camel%40j-davis.com

WAL records are divided into multiple categories called resource managers
(or SMGRs), whose definitions are in access/rmgr.h.  There is a list of the
in-core resource managers in access/rmgrlist.h.  XLogInsert(), which is the
window finishing the insertion of a WAL record built (see also section
"Write-Ahead Log Coding" in src/backend/access/transam/README for more
details), uses the ID of resource managers with would count as a record ID,
as one resource manager can have multiple types of records.

A resource manager is structured with a set of seven callbacks as of the
writing of this post.  These are defined in access/xlog_internal.h:

    typedef struct RmgrData
    {
        const char *rm_name;
        void        (*rm_redo) (XLogReaderState *record);
        void        (*rm_desc) (StringInfo buf, XLogReaderState *record);
        const char *(*rm_identify) (uint8 info);
        void        (*rm_startup) (void);
        void        (*rm_cleanup) (void);
        void        (*rm_mask) (char *pagedata, BlockNumber blkno);
        void        (*rm_decode) (struct LogicalDecodingContext *ctx,
                                  struct XLogRecordBuffer *buf);
    } RmgrData;

The commit mentioned above can have a huge impact for extension developers:
the possibility to define custom WAL records that would be automatically
replayed after a crash to ensure a consistent state, or replicated around.
Note that there are a few rules to remember:

  * A custom resource manager needs to be loaded with the GUC
  [shared\_preload\_libraries](https://www.postgresql.org/docs/devel/xfunc-c.html#XFUNC-SHARED-ADDIN).
  Modules require a call of RegisterCustomRmgr(), giving an ID for
  the custom RMGR and its set of callbacks.
  * If implementing your own custom RMGR, please register it on the
  [PostgreSQL wiki](https://wiki.postgresql.org/wiki/CustomWALResourceManagers),
  reserving its ID.  If your extension will not be open-sourced, there
  is likely no need to care about this step but be careful about potential
  conflicts as that could easily lead to corruption.
  * A node replaying a custom record has to load the same resource manager
  as the node that created this record.  In short, be careful about
  cross-node configuration *and* versioning of a custom resource manager
  as this is not tracked with XLOG\_PAGE\_MAGIC contrary to WAL records
  attached to in-core RMGRs and their WAL records.
  * [pg_waldump](https://www.postgresql.org/docs/devel/pgwaldump.html)
  does not know about custom RMGRs, except if patched.
  * [pg_walinspect](https://www.postgresql.org/docs/15/pgwalinspect.html),
  on the contrary, knows about custom RMGRs, as it is an extension attached
  to the backend.

The core code of PostgreSQL includes a base template for custom RMGRs in
src/test/modules/test\_custom\_rmgrs/, so feel free to refer to that when
trying to implement your own.  Custom RMGRs may be divided in a few categories,
roughly, with WAL records able to:

  * Force actions to happen when replaying such records on the nodes
  replaying them.
  * Act on some data to bring the system back to a consistent state (replay
  of a block image or some data, etc).  This is a game changer for extensions
  that implement custom table access methods, for example.

WAL is designed for the second category, still it is possible to have fun
with the first category with simple extensions, like this one called
[signal_rmgr](https://github.com/michaelpq/pg_plugins/tree/main/signal_rmgr),
developed with the sole purpose of getting a feeling how one would put in
place some basics for custom RMGRs for this post's sake.

The design of this extension is simple: register a WAL record on a primary
that would execute a signal on a standby's postmaster (or make a node signal
itself after a crash, which may not be a good idea).  The signals available
are SIGKILL, SIGHUP, SIGINT and SIGTERM, controlling a server reload or a
shutdown at distance, the timing of the operation being determined by the
moment the custom WAL record is replayed.  Here is the structure of the
module:

  * A SQL function that generates a custom record, with a signal and a
  custom string to give a "reason" behind the signal.
  * A "redo" callback, executing the signal on the postmaster and logging
  the reason.
  * A "desc" callback, to describe the contents of the record.
  * An "identity" callback, to describe the record types supported.

With this module in place, let's see what happens with a simple
primary/standby setup.  On the primary, let's do:

    =# CREATE EXTENSION signal_rmgr;
    CREATE EXTENSION
    =# SELECT signal_rmgr(1, 'Please reload.');
     signal_rmgr
    -------------
     0/3472BB8
    (1 row)

And here is what happens on the standby:

    LOG:  signal_rmgr_redo: signal 1, reason Please reload.
    CONTEXT:  WAL redo at 0/3472B78 for signal_rmgr/XLOG_SIGNAL_RMGR: signal 1; reason Please reload. (15 bytes)
    LOG:  sent signal 1 (Please reload.) to postmaster (21015)
    CONTEXT:  WAL redo at 0/3472B78 for signal_rmgr/XLOG_SIGNAL_RMGR: signal 1; reason Please reload. (15 bytes)
    LOG:  received SIGHUP, reloading configuration files

So far so good, the configuration has been reloaded on the standby after
replaying the WAL record.  Once again, on the primary:

    =# SELECT signal_rmgr(9, 'You are out, friend.');
     signal_rmgr
    -------------
     0/3472CE0
    (1 row)

And perhaps..  Just don't do that..

    CONTEXT:  WAL redo at 0/3472CA0 for signal_rmgr/XLOG_SIGNAL_RMGR: signal 9; reason You are out, friend. (21 bytes)
    LOG:  sent signal 9 (You are out, friend.) to postmaster (21015)
    CONTEXT:  WAL redo at 0/3472CA0 for signal_rmgr/XLOG_SIGNAL_RMGR: signal 9; reason You are out, friend. (21 bytes)
    DEBUG:  logger shutting down
