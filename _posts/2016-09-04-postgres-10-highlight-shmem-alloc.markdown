---
author: Michael Paquier
lastmod: 2016-09-04
date: 2016-09-04 07:16:22+00:00
layout: post
type: post
slug: postgres-10-highlight-shmem-alloc
title: 'Postgres 10 highlight - ShmemAlloc and ShmemAllocNoError'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 10
- memory
- error

---

While doing some work on Postgres 10, I have noticed that in a lot of code
paths some system calls related to memory allocation, like malloc(), realloc()
or strdup() simply missed to check for NULL values, causing a crash. Note that
crashes are highly unlikely to happen, still the result of this investigation
to make the code of Postgres cleaner, with problems detected as well by Heikki
Linnakangas and Aleksander Alekseev, has resulted on a set of commits, like
[that](https://git.postgresql.org/pg/commitdiff/d062245b5bd591edf6f78bab8d6b8bb3ff69c7a6),
[that](https://git.postgresql.org/pg/commitdiff/6f7c0ea32f808a7dad3ec07db7e5fdf6514d2af0)
and finally
[that](https://git.postgresql.org/pg/commitdiff/052cc223d5ce1b727f62afff75797c88d82f880b).

One extra thing, discovered by Aleksander, was related to the incorrect use of
ShmemAlloc(), which is a routine aimed at allocating shared memory for the
whole system. And the topic of this post is about specifically that, that
resulted in the
[following commit](https://git.postgresql.org/pg/commitdiff/6c03d981a6b64ed8caaed4e94b54ef926202c9f3):

    commit: 6c03d981a6b64ed8caaed4e94b54ef926202c9f3
    author: Tom Lane <tgl@sss.pgh.pa.us>
    date: Thu, 1 Sep 2016 10:13:55 -0400
    Change API of ShmemAlloc() so it throws error rather than returning NULL.

    A majority of callers seem to have believed that this was the API spec
    already, because they omitted any check for a NULL result, and hence
    would crash on an out-of-shared-memory failure.  The original proposal
    was to just add such error checks everywhere, but that does nothing to
    prevent similar omissions in future.  Instead, let's make ShmemAlloc()
    throw the error (so we can remove the caller-side checks that do exist),
    and introduce a new function ShmemAllocNoError() that has the previous
    behavior of returning NULL, for the small number of callers that need
    that and are prepared to do the right thing.  This also lets us remove
    the rather wishy-washy behavior of printing a WARNING for out-of-shmem,
    which never made much sense: either the caller has a strategy for
    dealing with that, or it doesn't.  It's not ShmemAlloc's business to
    decide whether a warning is appropriate.

    The v10 release notes will need to call this out as a significant
    source-code change.  It's likely that it will be a bug fix for
    extension callers too, but if not, they'll need to change to using
    ShmemAllocNoError().

First, as mentioned by the commit log, ShmemAlloc is a routine that originally
does not fail if an allocation error happens, logging a WARNING in case of
failure to let him know for which size it failed. That's not a problem in
itself, as long as the callers check for a NULL result and issue an error
message correctly. However, after looking at the call sites of this routine,
it happened that only few code paths actually do that. So after discussion
it has been decided to change how this behaves and make it issue an ERROR
by default in case of failure. An additional routine, called
ShmemAllocNoError(), has been created to provide the original behavior.

As there are a couple of code paths that need to take some actions when
an allocation failure happens, take for example ShmemInitStruct() that
needs to remove a shared memory segment reference from the existing index
before failing, extension and plugin developers should fallback to
ShmemAllocNoError() where ShmemAlloc() was previously used if there were
NULL-checks done.

If your extension code has been using ShmemAlloc() directly, like for example
to allocate some shared memory using the system hook shmem\_startup\_hook, be
sure that what you are doing is correct. As ShmemAlloc() is a rather
widely-used routine in plugin and extension code, be sure to check how your
existing code behaves, and then fix it. The release notes of Postgres 10 will
likely mention this behavior change, and this post is here to inform people a
bit earlier than that, so be aware of the change. One need to make sure as
well that any existing code compiled on versions older than 10 are doing the
correct job.
