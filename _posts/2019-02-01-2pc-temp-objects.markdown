---
author: Michael Paquier
lastmod: 2019-02-01
date: 2019-02-01 08:02:03+00:00
layout: post
type: post
slug: 2pc-temp-objects
title: 'Two-phase commit and temporary objects'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- bug
- transaction
- object

---

A couple of weeks ago a bug has popped up on the community mailing lists
about [the use of temporary objects in two-phase commit](https://www.postgresql.org/message-id/5d910e2e-0db8-ec06-dd5f-baec420513c3@imap.cc).
After discussions, the result is the following commit:

    commit: c5660e0aa52d5df27accd8e5e97295cf0e64f7d4
    author: Michael Paquier <michael@paquier.xyz>
    date: Fri, 18 Jan 2019 09:21:44 +0900
    Restrict the use of temporary namespace in two-phase transactions

    Attempting to use a temporary table within a two-phase transaction is
    forbidden for ages.  However, there have been uncovered grounds for
    a couple of other object types and commands which work on temporary
    objects with two-phase commit.  In short, trying to create, lock or drop
    an object on a temporary schema should not be authorized within a
    two-phase transaction, as it would cause its state to create
    dependencies with other sessions, causing all sorts of side effects with
    the existing session or other sessions spawned later on trying to use
    the same temporary schema name.

    Regression tests are added to cover all the grounds found, the original
    report mentioned function creation, but monitoring closer there are many
    other patterns with LOCK, DROP or CREATE EXTENSION which are involved.
    One of the symptoms resulting in combining both is that the session
    which used the temporary schema is not able to shut down completely,
    waiting for being able to drop the temporary schema, something that it
    cannot complete because of the two-phase transaction involved with
    temporary objects.  In this case the client is able to disconnect but
    the session remains alive on the backend-side, potentially blocking
    connection backend slots from being used.  Other problems reported could
    also involve server crashes.

    This is back-patched down to v10, which is where 9b013dc has introduced
    MyXactFlags, something that this patch relies on.

    Reported-by: Alexey Bashtanov
    Author: Michael Paquier
    Reviewed-by: Masahiko Sawada
    Discussion: https://postgr.es/m/5d910e2e-0db8-ec06-dd5f-baec420513c3@imap.cc
    Backpatch-through: 10

In PostgreSQL, temporary objects are assigned into a temporary namespace which
gets cleaned up automatically when the session ends, taking care consistently
of any object which are session-dependent.  This can include any types of
objects which can be schema-qualified: tables, functions, operators, or even
extensions (linked with a temporary schema).  The schema name is chosen based
on the position of the session in a backend array, prefixed with "pg\_temp\_",
hence it is perfectly possible to finish with different temporary namespace
names if reconnecting a session.  There are a couple of functions which can be
used to status of this schema:

  * pg\_my\_temp\_schema, to get the OID of the temporary schema used,
  useful when casted with "::regnamespace".
  * pg\_is\_other\_temp\_schema, to check if a schema is from the existing
  session or not.
  * At a certain degree, current\_schema and current\_schemas are also useful
  as they can display respectively the current schema in use and the schemas
  in "search\_path".  Note that it is possible to include directly "pg\_temp"
  in "search\_path" as an alias of the temporary schema, and that those
  functions will return the effective temporary schema name.

Here is an example with search\_path enforced to a temporary schema for those
functions:

    =# SET search_path = 'pg_temp';
    SET
    =# SELECT current_schema();
     current_schema
    ----------------
     pg_temp_3
    (1 row)
    =# SELECT pg_my_temp_schema()::regnamespace;
     pg_my_temp_schema
    -------------------
     pg_temp_3
    (1 row)
    =# SELECT pg_is_other_temp_schema(pg_my_temp_schema());
     pg_is_other_temp_schema
    -------------------------
     f
    (1 row)

One thing to note in this particular case is that current\_schema() may
finish by creating a temporary schema as it needs to return the real
temporary namespace associated to a session, and not an alias like
"pg\_temp" as in some cases the alias is not able to work with some
commands.  One example of that is CREATE EXTENSION specified to create
objects on the session's temporary schema (note that ALTER EXTENSION
cannot move an extension contents from a persistent schema to a temporary
one).

Another thing, essential to understand, is that all those temporary objects
are linked to a given session, but two-phase commit is not.  Hence, it is
perfectly possible to run PREPARE TRANSACTION in one session, and COMMIT
PREPARED in a second session.  The problem discussed in the thread mentioned
up-thread is that one could possibly associate temporary object within a
two-phase transaction, which is logically incorrect.  An effect of doing so
is that the temporary schema dropped at the end of a session would block
until the two-phase transaction is commit-prepared, blocking a backend
slot from being used, and potentially messing up upcoming sessions trying
to use the same temporary schema.  So if this effect accumulates and many
two-phase transactions are not committed, this could bloat the shared
memory areas for upcoming connections, preventing future connections.
Multiple object types may be involved, but there are other patterns like
LOCK on a temporary table within a transaction running two-phase commit,
or just the drop of a temporary object.  One visible effect is for example a
session waiting for a lock to be released, while the client thinks that
the session has actually finished, which could be accomplished with just
that:

    =# CREATE TEMP TABLE temp_tab (a int);
    CREATE TABLE
    =# BEGIN;
    BEGIN
    =# LOCK temp_tab IN ACCESS EXCLUSIVE MODE;
    LOCK TABLE
    =# PREPARE TRANSACTION '2pc_lock_temp';
    PREPARE TRANSACTION
    -- Leave the session
    =# \q

When patched, PREPARE TRANSACTION would just throw an error instead.

    =# PREPARE TRANSACTION '2pc_lock_temp';
    ERROR:  0A000: cannot PREPARE a transaction that has operated on temporary objects
    LOCATION:  PrepareTransaction, xact.c:2284

The fix here involves more restriction of two-phase transactions when
involving temporary objects, which has been on preventing only the use
of tables within such transactions for many years, so this tightens the
corner cases found.

Note that this found only its way down to Postgres 10, as the bug fix relies
on a session-level variable called MyXactFlags, which can be used in a
transaction to mark certain events.  And in the case of two-phase commit, the
flag is used to issue properly an error at PREPARE TRANSACTION phase so as
the state of the transaction does not mess up with the temporary namespace,
so as there are no after-effects with the existing session or a future session
trying to use the same temporary namespace.  It could be possible to lower
the restriction, particularly for temporary tables which use ON COMMIT
DROP, but that would be rather tricky to achieve so as it would need
special handling of temporary objects which now happens at COMMIT PREPARED
phase.
