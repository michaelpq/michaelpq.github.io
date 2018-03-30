---
author: Michael Paquier
lastmod: 2015-01-27
date: 2015-01-27 02:05:34+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-parallel-vacuum
title: 'Postgres 9.5 feature highlight - Parallel VACUUM with vacuumdb'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- vacuum
- parallel

---

A couple of days back a new mode has been added in [vacuumdb]
(http://www.postgresql.org/docs/devel/static/app-vacuumdb.html) for the
support of parallel jobs:

    commit: a17923204736d8842eade3517d6a8ee81290fca4
    author: Alvaro Herrera <alvherre@alvh.no-ip.org>
    date: Fri, 23 Jan 2015 15:02:45 -0300
    vacuumdb: enable parallel mode

    This mode allows vacuumdb to open several server connections to vacuum
    or analyze several tables simultaneously.

    Author: Dilip Kumar.  Some reworking by Álvaro Herrera
    Reviewed by: Jeff Janes, Amit Kapila, Magnus Hagander, Andres Freund

When specifying a number of jobs with -j, the number of maximum connections
defined by max\_connections should be higher than the number of jobs specified
as process creates a number of connections to the remote database equal to
the number of jobs, and then reuses those connections to process the tables
specified.

This of course supports all the modes already present in vacuumdb, like
--analyze, --analyze-in-stages, etc. The list of tables processed in
parallel can as well be customized when passing several values via --tables.

An important thing to note is that when using this feature with -f (VACUUM
FULL), there are risks of deadlocks when processing catalog tables. For
example in this case what happens was a conflict between pg\_index and
pg\_depend:

    $ vacuumdb -j 32 -f -d postgres
    vacuumdb: vacuuming database "postgres"
    vacuumdb: vacuuming of database "postgres" failed: ERROR:  deadlock detected
    DETAIL:  Process 2656 waits for RowExclusiveLock on relation 2608 of database 12974; blocked by process 2642.
    Process 2642 waits for AccessShareLock on relation 2610 of database 12974; blocked by process 2656.
    HINT:  See server log for query details.
    $ psql -At -c "SELECT relname FROM pg_class WHERE oid IN (2608,2610);"
    pg_index
    pg_depend

Note that this has higher chances to happen if:

  * the number of relations defined on the database processed is low.
  * the quantity of data to be processed is low
  * the number of jobs is high

So be careful when using parallel jobs with FULL on a complete database.
