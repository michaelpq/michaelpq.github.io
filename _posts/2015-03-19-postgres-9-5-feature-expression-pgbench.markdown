---
author: Michael Paquier
lastmod: 2015-03-19
date: 2015-03-19 12:52:52+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-expression-pgbench
title: 'Postgres 9.5 feature highlight - More flexible expressions in pgbench'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.5
- pgbench

---

A nice feature extending the usage of [pgbench]
(https://www.postgresql.org/docs/devel/static/pgbench.html), in-core
tool of Postgres aimed at doing benchmarks, has landed in 9.5 with this
commit:

    commit: 878fdcb843e087cc1cdeadc987d6ef55202ddd04
    author: Robert Haas <rhaas@postgresql.org>
    date: Mon, 2 Mar 2015 14:21:41 -0500
    pgbench: Add a real expression syntax to \set

    Previously, you could do \set variable operand1 operator operand2, but
    nothing more complicated.  Now, you can \set variable expression, which
    makes it much simpler to do multi-step calculations here.  This also
    adds support for the modulo operator (%), with the same semantics as in
    C.

    Robert Haas and Fabien Coelho, reviewed by Álvaro Herrera and
    Stephen Frost

pgbench has for ages support for custom input files using -f with custom
variables, variables that can be set with for example \set or \setrandom,
and then can be used in a custom set of SQL queries:

    \set id 10 * :scale
    \setrandom id2 1 :id
    SELECT name, email FROM users WHERE id = :id;
    SELECT capital, country FROM world_cities WHERE id = :id2;

Up to 9.4, those custom variables can be calculated with simple rules
of the type "var operator var2" (the commit message above is explicit
enough), resulting in many intermediate steps and variables when doing
more complicated calculations (note as well that additional operands and
variables, if provided, are simply ignored after the first three ones):

    \setrandom ramp 1 200
    \set scale_big :scale * 10
    \set min_big_scale :scale_big + :ramp
    SELECT :min_big_scale;

In 9.5, such cases become much easier because pgbench has been integrated
with a parser for complicated expressions. In the case of what is written
above, the same calculation can be done more simply with that, but far more
fancy things can be done:

    \setrandom ramp 1 200
    \set min_big_scale :scale * 10 + :ramp
    SELECT :min_big_scale;

With pgbench run for a couple of transactions, here is what you could get:

    $ pgbench -f test.sql -t 5
    [...]
    $ tail -n5 $PGDATA/pg_log/postgresql.log
    LOG:  statement: SELECT 157;
    LOG:  statement: SELECT 53;
    LOG:  statement: SELECT 32;
    LOG:  statement: SELECT 115;
    LOG:  statement: SELECT 43;

Another thing important to mention is that this commit has added as well
support for the operator modulo "%". In any case, be careful to not overdue
it with this feature, grouping expressions may be good for readability, but
doing it too much would make it hard to understand later on how a given
script has been designed.
