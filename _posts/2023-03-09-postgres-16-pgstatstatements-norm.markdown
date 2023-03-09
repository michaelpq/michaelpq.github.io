---
author: Michael Paquier
lastmod: 2023-03-09
date: 2023-03-09 11:25:32+00:00
layout: post
type: post
slug: postgres-16-pgstatstatements-norm
title: 'Postgres 16 highlight - Normalization of utilities in pg_stat_statements'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 16
- administration
- monitoring
- ddl

---

This post begins with this
[commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=daa8365)
added to Postgres 16:

    commit: daa8365a900729fe2a8d427fbeff19e763e35723
    author: Michael Paquier <michael@paquier.xyz>
    date: Wed, 8 Mar 2023 15:00:50 +0900
    Reflect normalization of query strings for utilities in pg_stat_statements

    Applying normalization changes how the following query strings are
    reflected in pg_stat_statements, by showing Const nodes with a
    dollar-signed parameter as this is how such queries are structured
    internally once parsed:
    - DECLARE
    - EXPLAIN
    - CREATE MATERIALIZED VIEW
    - CREATE TABLE AS

    More normalization could be done in the future depending on the parts
    where query jumbling is applied (like A_Const nodes?), the changes being
    reflected in the regression tests in majority created in de2aca2.  This
    just allows the basics to work for utility queries using Const nodes.

    Reviewed-by: Bertrand Drouvot
    Discussion: https://postgr.es/m/Y+MRdEq9W9XVa2AB@paquier.xyz

Actually, no.  I take it back.  That's wrong.  This post *finishes* with this
commit, and begins with this
[one](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=3db72eb):

    commit: 3db72ebcbe20debc6552500ee9ccb4b2007f12f8
    author: Michael Paquier <michael@paquier.xyz>
    date: Tue, 31 Jan 2023 15:24:05 +0900
    Generate code for query jumbling through gen_node_support.pl

    This commit changes the query jumbling code in queryjumblefuncs.c to be
    generated automatically based on the information of the nodes in the
    headers of src/include/nodes/ by using gen_node_support.pl.  This
    approach offers many advantages:
    - Support for query jumbling for all the utility statements, based on the
    state of their parsed Nodes and not only their query string.  This will
    greatly ease the switch to normalize the information of some DDLs, like
    SET or CALL for example (this is left unchanged and should be part of a
    separate discussion).  With this feature, the number of entries stored
    for utilities in pg_stat_statements is reduced (for example now
    "CHECKPOINT" and "checkpoint" mean the same thing with the same query
    ID).

    [...]

    Author: Michael Paquier
    Reviewed-by: Peter Eisentraut
    Discussion: https://postgr.es/m/Y5BHOUhX3zTH/ig6@paquier.xyz

Query jumbling is a concept that exists in
[pg\_stat\_statements](https://www.postgresql.org/docs/devel/pgstatstatements.html)
since Postgres 9.2, that consists in compiling hashes of queries based
on their binary parsed state, which is made of a series of nodes categorizing
the elements parsed (see src/include/nodes/ for more).  The main advantage
of query jumbling is to be able to normalize portions of the queries so as
constants are silenced.  For example, queries like "SELECT 1;" and
"SELECT 2;" compile the same hash, the node holding the constant value
being ignored.  Then, these are grouped under the same normalized query
string, as of "SELECT $1;", using as normalized string the first entry
found with such a hash (under entry deallocation this may be missed).
All that has been originally introduced in this
[commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=7313cc01),
where this applied to SELECT queries and DML (INSERT, UPDATE, DELETE and
more recently MERGE).

A more recent change is that query jumbling has been moved to the core code in
src/backend/ for Postgres 14 (see
[here](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=5fd9dfa)),
so as hashes of queries can be stored in some in-core structure, their
"Query", depending on the setting of the configuration parameter called
[compute\_query\_id](https://www.postgresql.org/docs/devel/runtime-config-statistics.html#RUNTIME-CONFIG-STATISTICS-MONITOR).
This offers the possibility for out-of-core modules, like extensions, to
consume in a consistent way the hashes of the queries consumed across all
these.

One of the new things added in Postgres 16 is that the code in charge of
doing the query jumbling is now automatically generated depending on the
definitions of the nodes in src/includes/nodes/, using what is called
internally pg\_node\_attr (as in src/include/nodes/nodes.h) to decide if
an entire node or one of its fields needs a special treatment for the
query jumbling, like being simply ignored.  This has a couple of advantages:

  * Document within the headers, where the nodes are defined, the reasons
  why a node attribute is applied.
  * Overall code reduction.
  * This applies to utility queries, DDLs and everything that's not in the
  category where the initial query jumbling was added.

This stage already has an effect of what gets reported in
pg\_stat\_statements, as all utility queries are grouped together not based
on a hash calculated from their string, but based on a hash computed from
their parsed node tree.  For example, all these queries mean the same thing,
still these would have generated three different entries in 15's
pg\_stat\_statements.  Now, in Postgres 16, we get that (note upper-case and
lower-case):

    =# VACUUM (FULL);
    VACUUM
    =# vacuum (full);
    VACUUM
    =# vacuum full;
    VACUUM
    =# CREATE EXTENSION pg_stat_statements;
    CREATE EXTENSION
    =# SELECT calls, query FROM pg_stat_statements
         WHERE lower(query) ~ 'vacuum';
     calls |     query
    -------+---------------
         3 | VACUUM (FULL)
    (1 row)

The value of the "query" field matches with the first query that has been
created for pg\_stat\_statements.

Finally comes the first commit mentioned at the top of the post: the
normalization of the utility queries, applying the same rules related to
constant values for all the query commands that include such things based
on their parsed state (note that I mean Const, not A_Const).  Take a CREATE
TABLE AS:

    =# SELECT calls, query FROM pg_stat_statements
         WHERE lower(query) ~ 'create table';
     calls |                  query                  
    -------+-----------------------------------------
         1 | CREATE TABLE norm_tab AS SELECT $1 AS a
    (1 row)

The capabilities are still limited, though the basics are in place to allow
much more in terms of normalization via the manipulation of utility nodes.
