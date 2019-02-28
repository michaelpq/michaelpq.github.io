---
author: Michael Paquier
lastmod: 2019-02-28
date: 2019-02-28 08:20:20+00:00
layout: post
type: post
slug: postgres-12-with-materialize
title: 'Postgres 12 highlight - WITH clause and materialization'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 12
- materialized
- query
- performance

---

Postgres 12 is bringing a game-changer regarding
[common table expressions](https://www.postgresql.org/docs/current/queries-with.html)
(named also CTE, defined by WITH clauses in SELECT queries) with the
following commit:

    commit: 608b167f9f9c4553c35bb1ec0eab9ddae643989b
    author: Tom Lane <tgl@sss.pgh.pa.us>
    date: Sat, 16 Feb 2019 16:11:12 -0500
    Allow user control of CTE materialization, and change the default behavior.

    Historically we've always materialized the full output of a CTE query,
    treating WITH as an optimization fence (so that, for example, restrictions
    from the outer query cannot be pushed into it).  This is appropriate when
    the CTE query is INSERT/UPDATE/DELETE, or is recursive; but when the CTE
    query is non-recursive and side-effect-free, there's no hazard of changing
    the query results by pushing restrictions down.

    Another argument for materialization is that it can avoid duplicate
    computation of an expensive WITH query --- but that only applies if
    the WITH query is called more than once in the outer query.  Even then
    it could still be a net loss, if each call has restrictions that
    would allow just a small part of the WITH query to be computed.

    Hence, let's change the behavior for WITH queries that are non-recursive
    and side-effect-free.  By default, we will inline them into the outer
    query (removing the optimization fence) if they are called just once.
    If they are called more than once, we will keep the old behavior by
    default, but the user can override this and force inlining by specifying
    NOT MATERIALIZED.  Lastly, the user can force the old behavior by
    specifying MATERIALIZED; this would mainly be useful when the query had
    deliberately been employing WITH as an optimization fence to prevent a
    poor choice of plan.

    Andreas Karlsson, Andrew Gierth, David Fetter

    Discussion: https://postgr.es/m/87sh48ffhb.fsf@news-spur.riddles.org.uk

Since their introduction, CTEs had always been materialized, meaning that
queries in WITH clauses are run once, with the resulting content added into
a temporary copy table, which is then reused by the outer query.  This can be
used as an optimization fence, and as mentioned in the commit message this
is useful for DML queries which include RETURNING when used in a CTE.  However
this can come with disadvantages.  Imagine for example this case:

    =# CREATE TABLE very_large_tab AS
         SELECT (random() * 1000000)::int4 AS id
         FROM generate_series(1,1000000) AS id;
    SELECT 1000000
    =# WITH large_scan AS (SELECT * FROM very_large_tab)
         SELECT * FROM large_scan WHERE id = 1;
     id
    ----
      1
    (1 row)

Here are the contents of a plan for the query above generated with Postgres
11, and the difference with 12:

    -- Plan with Postgres 11
    =# EXPLAIN (COSTS OFF) WITH large_scan AS (SELECT * FROM very_large_tab)
         SELECT * FROM large_scan WHERE id = 1;
                 QUERY PLAN
    ------------------------------------
     CTE Scan on large_scan
       Filter: (id = 1)
       CTE large_scan
         ->  Seq Scan on very_large_tab
    (4 rows)
    -- Plan with Postgres 12
                     QUERY PLAN
    -------------------------------------------
     Gather
       Workers Planned: 2
       ->  Parallel Seq Scan on very_large_tab
             Filter: (id = 1)
    (4 rows)

If the contents of the WITH clause are materialized, then all the contents
of the large table are copied into a temporary location, and then reused by
the main query as mentioned by the sequential scan in the previous plan for
Postgres 11.  The plan of Postgres 12 rewrites the query and pushes down the
condition down to the outer query.  Hence, in this simple example,
materializing the contents of the large table is very expensive, and the
query could be just written like that for this simple example, which is what
Postgres 12 does if the query does not use any recursion, and has, as
mentioned in the commit message, no side effect (take for example the use
of volatile functions in quals):

    =# SELECT * FROM very_large_tab WHERE id = 1;
     id
    ----
      1
    (1 row)

Changing the default is something to be aware of, and a second thing
which users need to know is that it is possible to enforce the default
materialization behavior using new options in the WITH clause called
MATERIALIZED or NOT MATERIALIZED.  In short, taking the previous example,
the plans of before and after this commit can be equally generated:

    =# EXPLAIN (COSTS OFF) WITH large_scan AS MATERIALIZED
         (SELECT * FROM very_large_tab)
       SELECT * FROM large_scan WHERE id = 1;
                 QUERY PLAN
    ------------------------------------
     CTE Scan on large_scan
       Filter: (id = 1)
       CTE large_scan
         ->  Seq Scan on very_large_tab
    (4 rows)
    =# EXPLAIN (COSTS OFF) WITH large_scan AS NOT MATERIALIZED
         (SELECT * FROM very_large_tab)
       SELECT * FROM large_scan WHERE id = 1;
                    QUERY PLAN
    -------------------------------------------
     Gather
       Workers Planned: 2
       ->  Parallel Seq Scan on very_large_tab
             Filter: (id = 1)
    (4 rows)

Note that if the outer query mentions the WITH clause more than once, then
the materialization will not happen.  With the options mentioned previously,
this can be of course enforced.
