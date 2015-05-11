---
author: Michael Paquier
lastmod: 2015-05-11
date: 2015-05-11 08:05:27+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-upsert
title: 'Postgres 9.5 feature highlight: Upsert'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- highlight
- feature
- 9.5
- upsert
- insert
- update
- conflict
- constraint
- primary
- key
- nothing

---

Marked as the number #1 wanted feature in Postgres that has been missing for
years by many people, [upsert](http://www.postgresql.org/docs/devel/static/sql-insert.html)
support has landed in the Postgres world and will be released with the upcoming
9.5:

    commit: 168d5805e4c08bed7b95d351bf097cff7c07dd65
    author: Andres Freund <andres@anarazel.de>
    date: Fri, 8 May 2015 05:31:36 +0200
    Add support for INSERT ... ON CONFLICT DO NOTHING/UPDATE.

    The newly added ON CONFLICT clause allows to specify an alternative to
    raising a unique or exclusion constraint violation error when inserting.
    ON CONFLICT refers to constraints that can either be specified using a
    inference clause (by specifying the columns of a unique constraint) or
    by naming a unique or exclusion constraint.  DO NOTHING avoids the
    constraint violation, without touching the pre-existing row.  DO UPDATE
    SET ... [WHERE ...] updates the pre-existing tuple, and has access to
    both the tuple proposed for insertion and the existing tuple; the
    optional WHERE clause can be used to prevent an update from being
    executed.  The UPDATE SET and WHERE clauses have access to the tuple
    proposed for insertion using the "magic" EXCLUDED alias, and to the
    pre-existing tuple using the table name or its alias.

    This feature is often referred to as upsert.

    [...]

    Author: Peter Geoghegan, with significant contributions from Heikki
    Linnakangas and Andres Freund. Testing infrastructure by Jeff Janes.
    Reviewed-By: Heikki Linnakangas, Andres Freund, Robert Haas, Simon Riggs,
    Dean Rasheed, Stephen Frost and many others.

For years, application developers have been using row triggers with a set
of dedicated functions to handle manually the case of UPSERT, as known as
how to deal on-the-fly with constraint violation when a tuple is inserted in
a relation. On top of being slow, because triggers add on the call stack the
overhead of a function call, many developers have for sure pested for a
feature that has been supported for years by the many RDBMS available, be
they proprietary or open source. Have a look for example at the function
merge\_db() defined [here]
(http://www.postgresql.org/docs/9.4/static/plpgsql-control-structures.html)
present in the documentation giving some insight of how to do it before
9.5 Upsert. Then let's see how this works with a simple table like this one:

    =# CREATE TABLE upsert_table (
      id int PRIMARY KEY,
	  sub_id int UNIQUE,
	  status text);
    CREATE TABLE
    =# INSERT INTO upsert_table VALUES (1, 1, 'inserted');
    INSERT 0 1
    =# INSERT INTO upsert_table VALUES (2, 2, 'inserted');
    INSERT 0 1

Upsert, being an extension of the INSERT query can be defined with two
different behaviors in case of a constraint conflict: DO NOTHING or DO
UPDATE.

In the latter case, the tuple inserted that conflicts with an existing
one will be simply ignored by the process.

    =# INSERT INTO upsert_table VALUES (2, 6, 'upserted')
       ON CONFLICT DO NOTHING RETURNING *;
     id | sub_id | status
    ----+--------+--------
    (0 rows)

Note as well that RETURNING returns nothing, because no tuples have been
inserted. Now with DO UPDATE, it is possible to perform operations on the
tuple there is a conflict with. First note that it is important to define
a constraint which will be used to define that there is a conflict.

    =# INSERT INTO upsert_table VALUES (2, 6, 'inserted')
       ON CONFLICT DO UPDATE SET status = 'upserted' RETURNING *;
    ERROR:  42601: ON CONFLICT DO UPDATE requires inference specification or constraint name
    LINE 1: ...NSERT INTO upsert_table VALUES (2, 6, 'inserted') ON CONFLIC...
    ^
    HINT:  For example, ON CONFLICT ON CONFLICT (<column>).
    LOCATION:  transformOnConflictArbiter, parse_clause.c:2306

If there is a constraint conflict with not the one defined in the ON
CONSTRAINT clause, the tuple will logically not be inserted in this case.
Well that's a normal error on table constraint:

    =# INSERT INTO upsert_table VALUES (2, 6, 'inserted')
       ON CONFLICT ON CONSTRAINT upsert_table_sub_id_key
	   DO UPDATE SET status = 'upserted' RETURNING *;
    ERROR:  23505: duplicate key value violates unique constraint "upsert_table_pkey"
    DETAIL:  Key (id)=(2) already exists.
    SCHEMA NAME:  public
    TABLE NAME:  upsert_table
    CONSTRAINT NAME:  upsert_table_pkey
    LOCATION:  _bt_check_unique, nbtinsert.c:423

If there is a conflict with the constraint defined and that there is still
a conflict with another constraint, the tuple is upserted:

    =# INSERT INTO upsert_table VALUES (2, 2, 'inserted')
       ON CONFLICT ON CONSTRAINT upsert_table_sub_id_key
	   DO UPDATE SET status = 'upserted' RETURNING *;
     id | sub_id |  status
    ----+--------+----------
      2 |      2 | upserted
    (1 row)
    UPSERT 0 1

Using the magic keyword EXCLUDED in the UPDATE clause used to update the
tuple there is a conflict with, it is possible to work on the values of
the tuple that is tried to be inserted:

    =# INSERT INTO upsert_table VALUES (3, 2, 'inserted')
       ON CONFLICT ON CONSTRAINT upsert_table_sub_id_key
	   DO UPDATE SET status = 'upserted', id = EXCLUDED.id RETURNING *;
     id | sub_id |  status
    ----+--------+----------
      3 |      2 | upserted
    (1 row)
    UPSERT 0 1

Note however that when there is a conflict with the value UPSERTed, there
is a constraint error, for both the constraint defined in the ON CONSTRAINT
clause and ones not in it:

    -- Conflict on id's PRIMARY KEY, not defined in ON CONSTRAINT
    =# INSERT INTO upsert_table VALUES (3, 2, 'inserted')
       ON CONFLICT ON CONSTRAINT upsert_table_sub_id_key
       DO UPDATE SET status = 'upserted 2', id = EXCLUDED.id - 2 RETURNING *;
    ERROR:  23505: duplicate key value violates unique constraint "upsert_table_pkey"
    DETAIL:  Key (id)=(1) already exists.
    SCHEMA NAME:  public
    TABLE NAME:  upsert_table
    CONSTRAINT NAME:  upsert_table_pkey
    LOCATION:  _bt_check_unique, nbtinsert.c:423
    -- Conflict on sub_id's UNIQUE constraint, defined in ON CONSTRAINT
    =# INSERT INTO upsert_table VALUES (3, 2, 'inserted')
       ON CONFLICT ON CONSTRAINT upsert_table_sub_id_key
	   DO UPDATE SET status = 'upserted 2', sub_id = EXCLUDED.sub_id - 1 RETURNING *;
    ERROR:  23505: duplicate key value violates unique constraint "upsert_table_sub_id_key"
    DETAIL:  Key (sub_id)=(1) already exists.
    SCHEMA NAME:  public
    TABLE NAME:  upsert_table
    CONSTRAINT NAME:  upsert_table_sub_id_key
    LOCATION:  _bt_check_unique, nbtinsert.c:423

As far as tested, this feature looks like a fine implementation of UPSERT
using a solid-rock infrastructure based on the concept of speculative insert.
In my opinion, mark the release of Postgres 9.5 on your agenda and be ready
to plan an upgrade window, this is going to reduce the trigger call stack
of a bunch of applications around!
