---
author: Michael Paquier
lastmod: 2015-04-21
date: 2015-04-21 13:37:33+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-frontend-allocation-routine
title: 'Postgres 9.5 feature highlight: palloc_extended for NULL result on OOM'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- highlight
- 9.5
- palloc
- flag
- frontend
- backend
- oom
- failure
- safe

---

Similarly to the post of a couple of weeks back relating about the
[new memory allocation routine]
(/postgresql-2/postgres-9-5-feature-highlight-allocation-routine-no-oom/)
able to give a plan B route in case of OOM, here is a follow-up commit
adding more infrastructure in the same area but this time for some
widely-used memory allocation routines:

    commit: 8c8a886268dfa616193dadc98e44e0715f884614
    author: Fujii Masao <fujii@postgresql.org>
    date: Fri, 3 Apr 2015 17:36:12 +0900
    Add palloc_extended for frontend and backend.

    This commit also adds pg_malloc_extended for frontend. These interfaces
    can be used to control at a lower level memory allocation using an interface
    similar to MemoryContextAllocExtended. For example, the callers can specify
    MCXT_ALLOC_NO_OOM if they want to suppress the "out of memory" error while
    allocating the memory and handle a NULL return value.

    Michael Paquier, reviewed by me.

palloc\_extended() is an equivalent of palloc() that operates on
CurrentMemoryContext (understand by that the current memory context a
process is using) with a set of flags, naming the same way for frontend
and backend:

  * MCXT\_ALLOC\_HUGE for allocations larger than 1GB. This flag has an
  effect on backend-side only, frontend routines using directly malloc.
  * MCXT\_ALLOC\_ZERO for zero allocation.
  * MCXT\_ALLOC\_NO\_OOM to bypass an ERROR message in case of an
  out-of-memory and return NULL to the caller instead. This is the real
  meat. In the case of frontends, not using this flag results in leaving
  with exit(1) immediately.

The advantage of this routine is that it is made available for both frontends
and backends, so when sharing code between both things, like xlogreader.c
used by [pg\_xlogdump](http://www.postgresql.org/docs/devel/static/pgxlogdump.html)
and [pg\_rewind](http://www.postgresql.org/docs/devel/static/app-pgrewind.html)
on frontend-side and by Postgres backend, consistent code can be used for
everything, making maintenance far easier.

A last thing to note is the addition of pg\_malloc\_extended(), which is
available only for frontends, which is a natural extension similar to what
already exists for pg\_malloc0(), pg\_realloc().
