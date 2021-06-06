---
author: Michael Paquier
lastmod: 2021-06-06
date: 2021-06-06 06:42:22+00:00
layout: post
type: post
slug: postgres-14-memory-dumps
title: 'Postgres 14 highlight - Memory dumps'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 14
- view
- memory
- function

---

PostgreSQL has gained two features that help in getting information about
the memory usage of sessions.  First, as of
[this commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=3e98c0b),
there is one new system view that reports the memory usage for a session:

    commit: 3e98c0bafb28de87ae095b341687dc082371af54
    author: Fujii Masao <fujii@postgresql.org>
    date: Wed, 19 Aug 2020 15:34:43 +0900
    Add pg_backend_memory_contexts system view.

    This view displays the usages of all the memory contexts of the server
    process attached to the current session. This information is useful to
    investigate the cause of backend-local memory bloat.

    [...]

    Author: Atsushi Torikoshi, Fujii Masao
    Reviewed-by: Tatsuhito Kasahara, Andres Freund, Daniel Gustafsson, Robert Haas, Michael Paquier
    Discussion: https://postgr.es/m/72a656e0f71d0860161e0b3f67e4d771@oss.nttdata.com

This view, called [pg\_backend\_memory\_contexts](https://www.postgresql.org/docs/devel/view-pg-backend-memory-contexts.html),
will display the current memory usage of the session attempting to access to
this view.  The implementation of such a feature is possible out-of-core, as
one has access to the low-level APIs and structures for memory structure,
mainly via src/include/nodes/memnodes.h, but it is nice to get access to
this facility without a dependency to an external module.

The logic starts from the TopMemoryContext and cascades down to each child
memory context, calling on the way a set of callbacks to grab all the
statistics for each memory context to print one tuple per memory context.
There are two extra things to track down the pyramidal structure of the
contexts: a depth level of each child and the name of the parent context.
Getting the memory statistics was also possible with a debugger after
logging into the host but that can prove to be annoying in our cloud-ish
days where logging into the host is not possible.  Aggregating this data
is an nice bonus as well here.

Note that by default access to this view is restricted to superusers, but
it can be granted to other roles.  One area where this is useful is the
possibility to track the amount of cache used by the session currently
connected, thanks to CacheMemoryContext that tracks the catalog and relation
caches:

    =# SELECT pg_size_pretty(sum(used_bytes)) AS cache_size
         FROM pg_backend_memory_contexts
         WHERE parent = 'CacheMemoryContext';
     cache_size
    ------------
     124 kB
    (1 row)

That is however limited, as this does not give the possibility to monitor
the activity of other sessions.  This is where the second feature of this
area can become useful, a function that allows to dump the memory usage of
other sessions in the logs, thanks to
[this commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=43620e3):

    commit: 43620e328617c1f41a2a54c8cee01723064e3ffa
    author: Fujii Masao <fujii@postgresql.org>
    date: Tue, 6 Apr 2021 13:44:15 +0900
    Add function to log the memory contexts of specified backend process.

    Commit 3e98c0bafb added pg_backend_memory_contexts view to display
    the memory contexts of the backend process. However its target process
    is limited to the backend that is accessing to the view. So this is
    not so convenient when investigating the local memory bloat of other
    backend process. To improve this situation, this commit adds
    pg_log_backend_memory_contexts() function that requests to log
    the memory contexts of the specified backend process.

    [...]

    Thanks to Tatsuhito Kasahara, Andres Freund, Tom Lane, Tomas Vondra,
    Michael Paquier, Kyotaro Horiguchi and Zhihong Yu for the discussion.

    Bump catalog version.

    Author: Atsushi Torikoshi
    Reviewed-by: Kyotaro Horiguchi, Zhihong Yu, Fujii Masao
    Discussion: https://postgr.es/m/0271f440ac77f2a4180e0e56ebd944d1@oss.nttdata.com

As per the hardcoded superuser check in this function, note that the execution
of this function cannot be granted to other roles, as it could be a cause for
DOS and bloat the logging collector by forcing writes of the statistics related
to the memory contexts for a wanted backend with one LOG-level entry for each
context.

    =# SELECT pg_log_backend_memory_contexts(6597);
     pg_log_backend_memory_contexts
    --------------------------------
     t
    (1 row)

The boolean status returned will be true if a process has been found when a
signal has been sent to it.  False is returned when the PID refers to a
process that may not exist or to a non-PostgreSQL process.  False is equally
returned if the process can be found but the signal to dump the memory usage
to the logs could not be sent.  Each LOG entry printed stores the same
information as the previous function, but note this does not include the
name of the immediate parent.  Instead, the entries are ordered.  Here is
for example an extract from the previous function run, showing the
beginning of the cache:

LOG:  level: 1; CacheMemoryContext: 1048576 total in 8 blocks; 480024 free (1 chunks); 568552 used
LOG:  level: 2; index info: 2048 total in 2 blocks; 496 free (1 chunks); 1552 used: pg_db_role_setting_databaseid_rol_index

A last thing to be aware of is that those logs are not returned to the client,
they are just printed in the server logs.
