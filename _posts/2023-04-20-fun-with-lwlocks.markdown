---
author: Michael Paquier
lastmod: 2023-04-20
date: 2023-04-20 03:59:22+00:00
layout: post
type: post
slug: 2023-04-20-fun-with-lwlocks
title: 'Postgres - Fun with LWLocks'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- lock

---

PostgreSQL lightweight-lock manager, with its interface in
src/include/storage/lwlock.h, is a facility aimed at controlling the access
to shared memory data structures.  One set of routines is at the center of
this post:

  * LWLockUpdateVar()
  * LWLockWaitForVar()
  * LWLockReleaseClearVar()

These are the least popular APIs related to lightweight locks used in the
PostgreSQL core code, being only used by the WAL insertion code to control
the locking around the backends doing the insertion of WAL records when
their writes happen.  Most of the code is located in xlog.c and the structure
called in shared memory called WALInsertLock that stores
NUM\_XLOGINSERT\_LOCKS locks (8 as of this post).  Increasing this value may
be worth studying its impact on WAL insert performance, still having more
of these induces an extra CPU cost to flushing the WAL where scans across
more locks would need to happen.  All the details around that are mostly
documented within XLogInsertRecord(), where the flow behind a WAL insertion
is explained (space reserved within a page, page boundary crossed, etc.).

The three routines mentioned above have a behavior clearly documented
in lwlock.c:

  * LWLockUpdateVar() requires first a lock to be acquired with
  LWLockAcquire().  This is in charge of updating a variable pointer
  located in shared memory to a new value, waking up any processes
  waiting for an update.
  * LWLockWaitForVar() can be used to wait for a variable to be updated.
  It should point to the same pointer as LWLockUpdateVar() so as a fresh
  value can be grabbed.
  * LWLockReleaseClearVar() would happen after as a last cleanup phase,
  resetting the variable to wait on to a default value.

As referring only to the PostgreSQL core code to get an idea of what
these routines can do may be limited when put into action, so I have written
a small module called
[lwlock\_test](https://github.com/michaelpq/pg_plugins/tree/main/lwlock_test)
that uses these APIs and is able to do the following, with two backends
able to play an automated ping-pong game, each one of them waiting for
variable updates coming from the other.  Here is how it works:

  * Two lightweight locks and two uint64 variables are put into shared
  memory, requiring shared\_preload\_libraries = 'lwlock\_test' in the
  server's postgresql.conf.
  * A first backend acquires one of the lightweight with LWLockAcquire(),
  * A second backend acquires the second lightweight lock, and waits for the
  first shared variable update with LWLockWaitForVar().
  * The first backend updates the first shared variable with
  LWLockUpdateVar(), then waits for an update of the second shared
  variable with LWLockWaitForVar().
  * The second backend receives the first variable update, and updates
  the second variable with LWLockUpdateVar(), going back to the second step.
  * All these steps repeat for a number of loops defined by the client.

As an effect of that, this extension comes with four SQL functions:

    =# \dx+ lwlock_test
      Objects in extension "lwlock_test"
              Object description
    --------------------------------------
     function lwlock_test_acquire()
     function lwlock_test_release()
     function lwlock_test_update(integer)
     function lwlock_test_wait(integer)

And mimicking the previous flow can be achieved with something like
that and two psql sessions (N > 1):

    Backend 1: SELECT lwlock_test_acquire();
    Backend 2: SELECT lwlock_test_wait(N);
    Backend 1: SELECT lwlock_test_update(N);
    Backend 1: SELECT lwlock_test_release();

If curious about grabbing more details about the flow of the exchange,
feel free to compile the extension with -DLWLOCK\_TEST\_DEBUG.  This
produces log messages each time an event happens in the waiter or the
updater process.  This is a compile flag to not slow down the potential
millions of exchanges that can happen.

One thing that should be pointed out is the flexibility of PostgreSQL
to give extensions ways to register lightweight locks of their own while
registering them into shared memory when loaded at startup.  Here is the
base structure used my the module that's allocated in shared memory, simply:

    typedef struct lwtSharedState
    {
            LWLock          *updater;
            LWLock          *waiter;
            uint64          updater_var;
            uint64          waiter_var;
    } lwtSharedState;

Then the allocation in shared memory comes in two steps, with two
different hooks as of HEAD:

  * shmem\_request\_hook\_type, to *ask* for a portion of shared resources,
  before doing any allocation.
  * shmem\_startup\_hook\_type, to *do* the allocation on the requested
  size.

Shared memory request ought to rely on RequestAddinShmemSpace(), and
lightweight lock requests need to go through RequestNamedLWLockTranche()
(see the module).  At allocation, concurrency is handled by a different
lightweight lock called AddinShmemInitLock, and GetNamedLWLockTranche()
would do the work to retrieve an array of locks that have been requested
previously.
