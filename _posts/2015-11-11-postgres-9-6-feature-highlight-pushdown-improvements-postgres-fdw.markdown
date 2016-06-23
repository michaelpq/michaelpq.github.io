---
author: Michael Paquier
lastmod: 2015-11-11
date: 2015-11-11 03:18:22+00:00
layout: post
type: post
slug: postgres-9-6-feature-highlight-pushdown-improvements-postgres-fdw
title: 'Postgres 9.6 feature highlight - operator and function pushdown with postgres_fdw'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- 9.6
- feature
- highlight
- postgres_fdw
- foreign
- data
- wrapper
- shippable
- pushdown
- function
- operator
- remote
- execution
- performance
- gain

---

The following commit has popped up not so long ago in the development branch
of Postgres 9.6:

    commit: d89494166351e1fdac77d87c6af500401deb2422
    author: Tom Lane <tgl@sss.pgh.pa.us>
    date: Tue, 3 Nov 2015 18:42:18 -0500
    Allow postgres_fdw to ship extension funcs/operators for remote execution.

    The user can whitelist specified extension(s) in the foreign server's
    options, whereupon we will treat immutable functions and operators of those
    extensions as candidates to be sent for remote execution.

    Whitelisting an extension in this way basically promises that the extension
    exists on the remote server and behaves compatibly with the local instance.
    We have no way to prove that formally, so we have to rely on the user to
    get it right.  But this seems like something that people can usually get
    right in practice.

    Paul Ramsey, hacked up a bit more by me

Up to 9.5, postgres\_fdw evaluates the shippability, or the possibility to
execute safely a given operator or function on a remote server instead of a
local using roughly three factors:

  * Is the object involved a built-in object?
  * Does this object use a safe collation? Verty roughly the collation needs
  to match DEFAULT\_COLLATION\_OID.
  * Does this object contain mutable functions? Basically anything that is
  not immutable (look at contain\_mutable\_functions in
  src/backend/optimizer/util/clauses.c to get a better idea)

If all conditions are satisfied, this function or operator is thought as
safe for remote execution, providing a huge performance gain particularly
if a query works on many tuples at once. If any of those conditions is not,
the function or operator will be executed locally after fetching all tuples
from the remote source.

The commit above, that will be present in Postgres 9.6 in the extension
[postgres\_fdw](http://www.postgresql.org/docs/devel/static/postgres-fdw.html),
brings an improvement in this area by leveraging the first condition. In short,
an object does not need anymore to be a built-in one to be considered as
shippable for remote execution: if an operator or function, which is
immutable, is part of a white-listed extension it will be flagged as
shippable with a new option that can be defined for a foreign-data-wrapper
SERVER. Let's see how this works in the context of postgres\_fdw by first
creating a FDW server looping back to itself:

    =# CREATE EXTENSION postgres_fdw;
    CREATE EXTENSION
    =# CREATE SERVER loopback_server
       FOREIGN DATA WRAPPER postgres_fdw
       OPTIONS (host 'localhost', port '5432', dbname 'postgres');
    CREATE SERVER
    =# CREATE USER MAPPING FOR PUBLIC SERVER loopback_server OPTIONS (password '');
    CREATE USER MAPPING
    =# CREATE FOREIGN TABLE tab_foreign (a int, b int)
       SERVER loopback_server OPTIONS (table_name 'tab');
    CREATE FOREIGN TABLE
    =# CREATE TABLE tab AS
       SELECT generate_series(1, 3, 1)  AS a,
              generate_series(3, 1, -1) AS b;
    SELECT 3

Also, let's add in the [blackhole extension]
(https://github.com/michaelpq/pg_plugins/tree/master/blackhole) an operator
and a function that will be used to check the white-listing shippability
(those operators or functions could be of a different type, it does not
matter here).

    =# CREATE EXTENSION blackhole;
    CREATE EXTENSION
    =# CREATE FUNCTION blackhole_sqrt(numeric) RETURNS numeric AS $$
       BEGIN
         RETURN sqrt($1);
       END
       $$ LANGUAGE plpgsql IMMUTABLE;
    CREATE FUNCTION
    =# CREATE OPERATOR /= (
         LEFTARG = numeric,
         RIGHTARG = numeric,
         PROCEDURE = numeric_eq,
         COMMUTATOR = /= );
    CREATE OPERATOR
    =# ALTER EXTENSION blackhole ADD FUNCTION blackhole_sqrt(numeric);
    ALTER EXTENSION
    =# ALTER EXTENSION blackhole ADD OPERATOR /= (numeric,numeric);
    ALTER EXTENSION
    =# \dx+ blackhole
    Objects in extension "blackhole"
           Object Description
    ----------------------------------
     function blackhole()
     function blackhole_sqrt(numeric)
     operator /=(numeric,numeric)
    (3 rows)

Now that everything is in place, let's see what happens when trying to
use those operators without marking them as part of what can be shipped
for remote execution.

    =# EXPLAIN (VERBOSE) SELECT * FROM tab_foreign WHERE a /= b;
                                     QUERY PLAN
    -----------------------------------------------------------------------------
     Foreign Scan on public.tab_foreign  (cost=100.00..206.00 rows=1280 width=8)
       Output: a, b
       Filter: ((tab_foreign.a)::numeric /= (tab_foreign.b)::numeric)
       Remote SQL: SELECT a, b FROM public.tab
    (4 rows)
    =# EXPLAIN (VERBOSE) SELECT * FROM tab_foreign WHERE a = blackhole_sqrt(b);
                                       QUERY PLAN
    ---------------------------------------------------------------------------------
     Foreign Scan on public.tab_foreign  (cost=100.00..846.00 rows=13 width=8)
       Output: a, b
       Filter: ((tab_foreign.a)::numeric = blackhole_sqrt((tab_foreign.b)::numeric))
       Remote SQL: SELECT a, b FROM public.tab
    (4 rows)

In both cases all tuples are first fetched from the remote source, then the
operator and functions are applied locally. Now, let's see the difference when
the blackhole extension needs is whitelisted so as its immutable functions and
operators can be taken into account by postgres\_fdw's FDW server. This can for
example be done using ALTER SERVER:

    =# ALTER SERVER loopback_server OPTIONS (ADD extensions 'blackhole');
    ALTER SERVER
    =# EXPLAIN (VERBOSE) SELECT * FROM tab_foreign WHERE a /= b;
                                     QUERY PLAN
    -----------------------------------------------------------------------------
    Foreign Scan on public.tab_foreign  (cost=100.00..180.40 rows=1280 width=8)
    Output: a, b
    Remote SQL: SELECT a, b FROM public.tab WHERE ((a OPERATOR(public./=) b))
    (3 rows)
    =# EXPLAIN (VERBOSE) SELECT * FROM tab_foreign WHERE a = blackhole_sqrt(b);
                                        QUERY PLAN
    ----------------------------------------------------------------------------------
     Foreign Scan on public.tab_foreign  (cost=100.00..795.06 rows=13 width=8)
       Output: a, b
       Remote SQL: SELECT a, b FROM public.tab WHERE ((a = public.blackhole_sqrt(b)))
    (3 rows)

And this time both are part of the query string generated for remote
execution. If such a query needs to fetch many tuples from a remote source
but only a few portion of them matched the condition of the operator or
function, this is a huge performance gain.

When using this option, as the functions and operators will be sent to the
remote server, be sure that the extension is installed there as well or
this query execution will just fail. That is a matter of being consistent
between the local server and the remote one.
