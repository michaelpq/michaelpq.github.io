---
author: Michael Paquier
lastmod: 2018-06-03
date: 2018-06-03 08:03:22+00:00
layout: post
type: post
slug: postgres-11-partition-pruning
title: 'Postgres 11 highlight - More Partition Pruning'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 11
- partition
- planner

---

While PostgreSQL 10 has introduced the basic infrastructure for in-core
support of partitioned tables, many new features are introduced in
11 to make the use of partitioned tables way more instinctive.  One
of them is an executor improvement for partition pruning, which has
been mainly introduced by commit
[499be01](https://git.postgresql.org/pg/commitdiff/499be013de65242235ebdde06adb08db887f0ea5):

    commit: 499be013de65242235ebdde06adb08db887f0ea5
    author: Alvaro Herrera <alvherre@alvh.no-ip.org>
    date: Sat, 7 Apr 2018 17:54:39 -0300
    Support partition pruning at execution time

    Existing partition pruning is only able to work at plan time, for query
    quals that appear in the parsed query.  This is good but limiting, as
    there can be parameters that appear later that can be usefully used to
    further prune partitions

    [... long text ...]

    Author: David Rowley, based on an earlier effort by Beena Emerson
    Reviewers: Amit Langote, Robert Haas, Amul Sul, Rajkumar Raghuwanshi,
    Jesper Pedersen
    Discussion: https://postgr.es/m/CAOG9ApE16ac-_VVZVvv0gePSgkg_BwYEV1NBqZFqDR2bBE0X0A@mail.gmail.com

This is a shortened extract (you can refer to the link above for the
full commit log which would bloat this blog entry).

First note that PostgreSQL 10 already has support for partition pruning
at planner time (the term "pruning" is new as of version 11 though),
which is a way to eliminate scans of entire child partitions depending
on the quals of a query (set of conditions in WHERE clause).  Let's
take an example with the following, simple, table using a single column
based on value ranges for the partition definition:

    =# CREATE TABLE parent_tab (id int) PARTITION BY RANGE (id);
    CREATE TABLE
    =# CREATE TABLE child_0_10 PARTITION OF parent_tab
         FOR VALUES FROM (0) TO (10);
    CREATE TABLE
    =# CREATE TABLE child_10_20 PARTITION OF parent_tab
         FOR VALUES FROM (10) TO (20);
    CREATE TABLE
    =# CREATE TABLE child_20_30 PARTITION OF parent_tab
         FOR VALUES FROM (20) TO (30);
    CREATE TABLE
    =# INSERT INTO parent_tab VALUES (generate_series(0,29));
    INSERT 0 30

This applies also to various operations, like ranges of values, as
well as additional OR conditions.  For example here only two out
of the three partitions are logically scanned:

    =# EXPLAIN SELECT * FROM parent_tab WHERE id = 5 OR id = 25;
                                QUERY PLAN
    -------------------------------------------------------------------
     Append  (cost=0.00..96.50 rows=50 width=4)
       ->  Seq Scan on child_0_10  (cost=0.00..48.25 rows=25 width=4)
             Filter: ((id = 5) OR (id = 25))
       ->  Seq Scan on child_20_30  (cost=0.00..48.25 rows=25 width=4)
             Filter: ((id = 5) OR (id = 25))
    =# EXPLAIN SELECT * FROM parent_tab WHERE id >= 5 AND id <= 15;
                            QUERY PLAN
    -------------------------------------------------------------------
     Append  (cost=0.00..96.50 rows=26 width=4)
       ->  Seq Scan on child_0_10  (cost=0.00..48.25 rows=13 width=4)
             Filter: ((id >= 5) AND (id <= 15))
       ->  Seq Scan on child_10_20  (cost=0.00..48.25 rows=13 width=4)
             Filter: ((id >= 5) AND (id <= 15))
    (5 rows)

When using several levels of partitions, this works as well, first
let's add an extra layer, bringing the partition tree to have this
shape:

           ---------parent_tab------------
          /        |           |          \
         /         |           |           \
     child_0_10 child_10_20 child_20_30 child_30_40
                                         /       \
                                        /         \
                                       /           \
                                 child_30_35  child_35_40

And this tree can be done with the following SQL queries:

    =# CREATE TABLE child_30_40 PARTITION OF parent_tab
         FOR VALUES FROM (30) TO (40)
         PARTITION BY RANGE(id);
    CREATE TABLE
    =# CREATE TABLE child_30_35 PARTITION OF child_30_40
         FOR VALUES FROM (30) TO (35);
    =# CREATE TABLE child_35_40 PARTITION OF child_30_40
         FOR VALUES FROM (35) TO (40);
    CREATE TABLE
    =# INSERT INTO parent_tab VALUES (generate_series(30,39));
    INSERT 0 10

When selecting partitions which involve multiple layers the planner
gets also the call, for example here:

    =# EXPLAIN SELECT * FROM parent_tab WHERE id = 10 OR id = 37;
                                QUERY PLAN
    -------------------------------------------------------------------
     Append  (cost=0.00..96.50 rows=50 width=4)
       ->  Seq Scan on child_10_20  (cost=0.00..48.25 rows=25 width=4)
             Filter: ((id = 10) OR (id = 37))
       ->  Seq Scan on child_35_40  (cost=0.00..48.25 rows=25 width=4)
             Filter: ((id = 10) OR (id = 37))
    (5 rows)

Note of course that this can happen only when the planner can know the
values it needs to evaluate, so for example using a non-immutable
function in a qual results into all the partitions scanned.  If a
partition is large, you also most likely want to create indexes on
them to switch to reduce the scan cost.

In PostgreSQL 10, there is also a user-level parameter which allows to
control if the pruning can happen or not with constraint\_exclusion, which
actually also works with the trigger-based partitioning with inherited
tables only driven by CHECK constraints.

Note that things have changed a bit in PostgreSQL 11 with the apparition
of the parameter called enable\_partition\_pruning, which is in charge of
controlling the discard of partitions when planner-time clauses are
selective enough to do the work, causing constraint\_exclusion to
have no effect with the previous examples.  So be careful if you used
PostgreSQL 10 with partitioning and the previous parameter. (Note as
well that constraint_exclusion has gained as value "partition" which
makes the constraint exclusion working on relations working on
inheritance partitions).

Now that things are hopefully clearer, finally comes the new feature
introduced in PostgreSQL 11, which is this time partition pruning at
*execution* time, which extends the somewhat-limited feature described
until now in this post.  This is an advantage in a couple of cases,
those being for example of a PREPARE query, a value from a subquery,
or parameterized value of nested loop joins (in which case partition
pruning can happen multiple times if the parameter value is changed
during execution).

Let's for example take the case of a subquery, where even if pruning
is enabled that no partitions are discarded.  This plan is the same
for PostgreSQL 10 and 11:

    =# EXPLAIN SELECT * FROM parent_tab WHERE id = (SELECT 1);
                                QUERY PLAN
    -------------------------------------------------------------------
     Append  (cost=0.01..209.38 rows=65 width=4)
       InitPlan 1 (returns $0)
         ->  Result  (cost=0.00..0.01 rows=1 width=4)
       ->  Seq Scan on child_0_10  (cost=0.00..41.88 rows=13 width=4)
             Filter: (id = $0)
       ->  Seq Scan on child_10_20  (cost=0.00..41.88 rows=13 width=4)
             Filter: (id = $0)
       ->  Seq Scan on child_20_30  (cost=0.00..41.88 rows=13 width=4)
             Filter: (id = $0)
        ->  Seq Scan on child_30_35  (cost=0.00..41.88 rows=13 width=4)
             Filter: (id = $0)
       ->  Seq Scan on child_35_40  (cost=0.00..41.88 rows=13 width=4)
             Filter: (id = $0)
    (13 rows)

Something that changes though, is that you should look at the output
of EXPLAIN ANALYZE which appends to non-executed partitions the term
"(never executed)".  Hence, with the previous query and version 11,
the following will be found (output changed a bit to adapt to this
blog as the part about the non-execution of each partition is appended
at the end of each sequential scan line):

    =# EXPLAIN ANALYZE SELECT * FROM parent_tab WHERE id = (select 1);
                                                     QUERY PLAN
    ------------------------------------------------------------------------------------------------------------
     Append  (cost=0.01..209.71 rows=65 width=4)
        (actual time=0.064..0.072 rows=1 loops=1)
      InitPlan 1 (returns $0)
       ->  Result  (cost=0.00..0.01 rows=1 width=4)
             (actual time=0.003..0.004 rows=1 loops=1)
       ->  Seq Scan on child_0_10  (cost=0.00..41.88 rows=13 width=4)
             (actual time=0.045..0.052 rows=1 loops=1)
             Filter: (id = $0)
             Rows Removed by Filter: 9
       ->  Seq Scan on child_10_20  (cost=0.00..41.88 rows=13 width=4)
             (never executed)
             Filter: (id = $0)
       ->  Seq Scan on child_20_30  (cost=0.00..41.88 rows=13 width=4)
             (never executed)
             Filter: (id = $0)
       ->  Seq Scan on child_30_35  (cost=0.00..41.88 rows=13 width=4)
             (never executed)
             Filter: (id = $0)
       ->  Seq Scan on child_35_40  (cost=0.00..41.88 rows=13 width=4)
             (never executed)
             Filter: (id = $0)
     Planning Time: 0.614 ms
     Execution Time: 0.228 ms
    (16 rows)

When using PREPARE queries though, you could rely on the EXPLAIN to get a
similar experience with the following queries, so feel free to check by
yourself:

    PREPARE parent_tab_scan (int) AS (SELECT * FROM parent_tab WHERE id = $1);
    EXPLAIN EXECUTE parent_tab_scan(1);

So be careful of any EXPLAIN output, and refer to what EXPLAIN ANALYZE
has to say when it comes to pruning at execution time for the case
where the values (or set of values) used for the pruning are only
known during the execution.  One part where "(never executed)" can apply
though is when using for example subqueries within the PREPARE statement.
Feel free to retry the previous queries for that.

