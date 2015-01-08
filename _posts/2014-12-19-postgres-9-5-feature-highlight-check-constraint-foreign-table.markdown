---
author: Michael Paquier
lastmod: 2014-12-19
date: 2014-12-19 02:01:54+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-check-constraint-foreign-table
title: 'Postgres 9.5 feature highlight: CHECK constraints for foreign tables'
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
- foreign
- data
- wrapper
- check
- constraint
- declarative
- planner
- performance
- remote
- save

---

Foreign tables are getting step-by-step closer to the features that are present
in normal relations with the addition of support for CHECK constraints.

    commit: fc2ac1fb41c2defb8caf825781af75db158fb7a9
    author: Tom Lane <tgl@sss.pgh.pa.us>
    date: Wed, 17 Dec 2014 17:00:53 -0500
    Allow CHECK constraints to be placed on foreign tables.

    As with NOT NULL constraints, we consider that such constraints are merely
    reports of constraints that are being enforced by the remote server (or
    other underlying storage mechanism).  Their only real use is to allow
    planner optimizations, for example in constraint-exclusion checks.  Thus,
    the code changes here amount to little more than removal of the error that
    was formerly thrown for applying CHECK to a foreign table.

    (In passing, do a bit of cleanup of the ALTER FOREIGN TABLE reference page,
    which had accumulated some weird decisions about ordering etc.)

    Shigeru Hanada and Etsuro Fujita, reviewed by Kyotaro Horiguchi and
    Ashutosh Bapat

As the constraint evaluation is not done on the PostgreSQL side (it is
the responsability of the remote source to perform the constraint checks),
what is done here is more allowing systems to do consistent CHECK
declarations on both the remote and local side. This is useful for the
planner as it can take advantage of that by performing plan optimizations
that get consistent plans across the remote and local sources, particularly
in the case where the remote source is a PostgreSQL server itself.

This behavior is similar to NOT NULL, the constraint check being done on
remote side. For example in the case of a single instance of Postgres
linked to itself, even if the constraint is defined locally but not
remotely there is nothing happening.

    =# CREATE EXTENSION postgres_fdw;
    CREATE EXTENSION
    =# CREATE SERVER postgres_server FOREIGN DATA WRAPPER postgres_fdw
        OPTIONS (host 'localhost', port '5432', dbname 'postgres');
    CREATE SERVER
    =# CREATE USER MAPPING FOR PUBLIC SERVER postgres_server
    OPTIONS (password '');
	CREATE USER MAPPING
    =# CREATE TABLE tab AS SELECT 1 AS a,
             generate_series(1,3) AS b,
             generate_series(1,3) AS c;
    SELECT 3
    =# CREATE FOREIGN TABLE tab_foreign (a int, b int, c int not null)
       SERVER postgres_server OPTIONS (table_name 'tab');
    CREATE FOREIGN TABLE
    =# INSERT INTO tab_foreign VALUES (1,2,null);
	INSERT 0 1

And then for CHECK:

    =# CREATE FOREIGN TABLE tab_foreign2
       (a int, b int, c int, CHECK (a > 0))
       SERVER postgres_server OPTIONS (table_name 'tab');
    CREATE FOREIGN TABLE
	=# INSERT INTO tab_foreign2 VALUES (-1,2,3);
	INSERT 0 1
	=# SELECT * FROM tab_foreign2;
     a  | b |  c
    ----+---+------
      1 | 1 |    1
      1 | 2 |    2
      1 | 3 |    3
      1 | 2 | null
     -1 | 2 |    3
	(5 rows)

This feature finds its power in planner optimizations as mentioned above,
then let's have a look at how it works. Using [constraint\_exclusion]
(http://www.postgresql.org/docs/devel/static/runtime-config-query.html#RUNTIME-CONFIG-QUERY-OTHER)
is particularly useful to enforce the constraint check on all the tables
as its default value, "partition", can only be used on inheritance child
tables and UNION ALL subqueries.

    =# SHOW constraint_exclusion;
     constraint_exclusion
    ----------------------
     partition
    (1 row)
	=# EXPLAIN VERBOSE SELECT * FROM tab_foreign2 WHERE a < 0;
	                                  QUERY PLAN
	------------------------------------------------------------------------------
     Foreign Scan on public.tab_foreign2  (cost=100.00..153.60 rows=758 width=12)
       Output: a, b, c
       Remote SQL: SELECT a, b, c FROM public.aa WHERE ((a < 0))
    (3 rows)
	=# SET constraint_exclusion TO on;
	SET
	=# EXPLAIN VERBOSE SELECT * FROM tab_foreign2 WHERE a < 0;
	                QUERY PLAN
	------------------------------------------
     Result  (cost=0.00..0.01 rows=1 width=0)
       Output: a, b, c
       One-Time Filter: false
    (3 rows)

See? In the case where the WHERE clause is incompatible with CHECK, the
planner is smart enough to conclude by itself that it cannot fetch tuples
from remote source, saving some resources at the same time.
