---
author: Michael Paquier
lastmod: 2015-02-01
date: 2015-02-01 12:20:22+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-allocation-routine-no-oom
title: 'Postgres 9.5 feature highlight - Allocation routine suppressing OOM error'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.5
- memory
- error

---

A couple of days ago the following commit has popped up in PostgreSQL
tree for the upcoming 9.5, introducing a feature particularly interesting
for developers of backend extensions and plugins:

    commit: bd4e2fd97d3db84bd970d6051f775b7ff2af0e9d
    author: Robert Haas <rhaas@postgresql.org>
    date: Fri, 30 Jan 2015 12:56:48 -0500
    Provide a way to supress the "out of memory" error when allocating.

    Using the new interface MemoryContextAllocExtended, callers can
    specify MCXT_ALLOC_NO_OOM if they are prepared to handle a NULL
    return value.

    Michael Paquier, reviewed and somewhat revised by me.

The memory allocation routines are located in the code of PostgreSQL
in mcxt.c while being declared in palloc.h, the most famous routines
of this set being palloc(), palloc0(), or repalloc() which work on
CurrentMemoryContext. There are as well some higher-level routines called
MemoryContextAlloc* able to perform allocations in a memory context
specified by caller. Using those routines it is possible to allocate
memory in any context other than the current one. Each existing allocation
routine share a common property: when allocation request cannot be
completed because of an out-of-memory error, process simply errors out,
contrary to what a malloc() would do by returning a NULL pointer to the
caller with ENONEM set as errno.

The commit above introduces in backend code a routine allowing to bypass
this out-of-memory error and get back a NULL pointer if system runs out
of memory, something particularly useful for features having a plan B
if plan A that needed a certain amount of allocated buffer could not
get the memory wanted. Let's imagine for example the case of a backend
process performing some compression of data using a custom data type.
If compression buffer cannot be allocated, process can store the data
as-is instead of failing, making this case more robust.

So, the new routine is called MemoryContextAllocExtended, and comes
with three control flags:

  * MCXT\_ALLOC\_HUGE, to perform allocations higher than 1GB. This is
  equivalent to MemoryContextAllocHuge if this flag is used alone.
  * MCXT\_ALLOC\_NO\_OOM, to avoid any ERROR message when an OOM shows
  up. This is the real meat of the feature.
  * MCXT\_ALLOC\_ZERO, to fill in memory allocated with zeros. This
  is equivalent to MemoryContextAllocZero if this flag is used alone.

Something worth noticing is that the combination of MCXT\_ALLOC\_HUGE
and MCXT\_ALLOC\_ZERO is something that even the existing routines
cannot do. Now, using this new routine let's do something actually useless
with it, as known as allocating a custom amount of memory, free'd
immediately after, using a custom function defined as followed:

    CREATE FUNCTION mcxtalloc_extended(size int,
        is_huge bool,
        is_no_oom bool,
        is_zero bool)
    RETURNS bool
    AS 'MODULE_PATHNAME'
    LANGUAGE C STRICT; 

And this function is coded like this:

    Datum
    mcxtalloc_extended(PG_FUNCTION_ARGS)
    {
        Size    alloc_size = PG_GETARG_UINT32(0);
        bool    is_huge = PG_GETARG_BOOL(1);
        bool    is_no_oom = PG_GETARG_BOOL(2);
        bool    is_zero = PG_GETARG_BOOL(3);
        int     flags = 0;
        char   *ptr;

        if (is_huge)
            flags |= MCXT_ALLOC_HUGE;
        if (is_no_oom)
            flags |= MCXT_ALLOC_NO_OOM;
        if (is_zero)
            flags |= MCXT_ALLOC_ZERO;
        ptr = MemoryContextAllocExtended(CurrentMemoryContext,
                alloc_size, flags);
        if (ptr != NULL)
        {
            pfree(ptr);
            PG_RETURN_BOOL(true);
        }
        PG_RETURN_BOOL(false);
    }

In an environment with low-memory, a huge allocation fails as follows:

    -- Kick an OOM
    =# SELECT mcxtalloc_extended(1024 * 1024 * 1024 - 1, false, false, false);
    ERROR:  out of memory
    DETAIL:  Failed on request of size 1073741823.

But with the new extended option MCXT\_ALLOC\_NO\_OOM the error is avoided,
giving more options to plugin as well as in-core developers:

    =# SELECT mcxtalloc_extended(1024 * 1024 * 1024 - 1, false, true, false);
     mcxtalloc_extended
    --------------------
     f
    (1 row)

Just for people wondering: this code is available in pg\_plugins [here]
(https://github.com/michaelpq/pg_plugins/tree/master/mcxtalloc_test).
