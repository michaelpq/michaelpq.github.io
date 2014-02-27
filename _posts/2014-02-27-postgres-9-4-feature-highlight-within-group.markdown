---
author: Michael Paquier
comments: true
lastmod: 2014-02-27
date: 2014-02-27 12:01:34+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-within-group
title: 'Postgres 9.4 feature highlight: WITHIN GROUP and ordered-set aggregates'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.4
- open source
- database
- development
- aggregate
- within
- group
- order
- set
- generic
- specification
- sql
- rank
- percentile
---
PostgreSQL 9.4 is going to be shipped with a feature called ordered-set
aggregates. This can be used with a new clause called WITHIN GROUP. All
those things have been introduced by the following commit.

    commit 8d65da1f01c6a4c84fe9c59aeb6b7e3adf870145
    Author: Tom Lane <tgl@sss.pgh.pa.us>
    Date:   Mon Dec 23 16:11:35 2013 -0500

    Support ordered-set (WITHIN GROUP) aggregates.

    This patch introduces generic support for ordered-set and hypothetical-set
    aggregate functions, as well as implementations of the instances defined in
    SQL:2008 (percentile_cont(), percentile_disc(), rank(), dense_rank(),
    percent_rank(), cume_dist()).  We also added mode() though it is not in the
    spec, as well as versions of percentile_cont() and percentile_disc() that
    can compute multiple percentile values in one pass over the data.

    Unlike the original submission, this patch puts full control of the sorting
    process in the hands of the aggregate's support functions.  To allow the
    support functions to find out how they're supposed to sort, a new API
    function AggGetAggref() is added to nodeAgg.c.  This allows retrieval of
    the aggregate call's Aggref node, which may have other uses beyond the
    immediate need.  There is also support for ordered-set aggregates to
    install cleanup callback functions, so that they can be sure that
    infrastructure such as tuplesort objects gets cleaned up.

    In passing, make some fixes in the recently-added support for variadic
    aggregates, and make some editorial adjustments in the recent FILTER
    additions for aggregates.  Also, simplify use of IsBinaryCoercible() by
    allowing it to succeed whenever the target type is ANY or ANYELEMENT.
    It was inconsistent that it dealt with other polymorphic target types
    but not these.

    Atri Sharma and Andrew Gierth; reviewed by Pavel Stehule and Vik Fearing,
    and rather heavily editorialized upon by Tom Lane

To put it in simple words, this feature allows doing operations on a group of
rows organized with ORDER BY thanks to the clause WITHIN GROUP.

As mentionned in the commit message, this is part of the SQL specification of
2008, with some additions like the function mode().

Before having that, doing such operations was not that straight-forward as
you would have needed for example a CTE coupled with a window function to
do it, needing to first order the entire set, and then do some post-processing
on what is wanted. Here is for example how to get a percentile (meaning that
for a subset of rows already ordered with a certain ORDER BY condition you
would fetch back from the subset the value which could be used to recover
only a given portions of rows of this subset, given by a percentage). So...
For the example... Here is how to get the 25th, 50th, 75th and 100th
percentile of a simple table with 20 rows.

    =# CREATE TABLE aa AS SELECT generate_series(1,20) AS a;
    SELECT 20
    =# WITH subset AS (
        SELECT a AS val,
            ntile(4) OVER (ORDER BY a) AS tile
        FROM aa
    )
    SELECT tile, max(val)
    FROM subset GROUP BY tile ORDER BY tile;
     tile | max
    ------+-----
        1 |   5
        2 |  10
        3 |  15
        4 |  20
    (4 rows)

The idea here is simply to divide the set of rows into buckets using ntile
and then to fetch back the maximum value of each tile corresponding to the
percentile wanted. For a larger table you might want to simply use ntile
with 100, this is not really complicated, but not that straight-forward
either.

And now here is how to do the same thing with Postgres 9.4 using WITHIN
GROUP for a single percentile value:

    =# SELECT percentile_disc(0.25)
          WITHIN GROUP (ORDER BY a) as max
       FROM aa;
     max
    -----
       5
    (1 row)

And for an array of percentiles:

    =# SELECT unnest(percentile_disc(array[0.25,0.5,0.75,1])
           WITHIN GROUP (ORDER BY a))
       FROM aa;
     unnest
    --------
          5
         10
         15
         20
    (4 rows)

This is way simpler.

Note that not all the aggregate functions can be used with WITHIN
CLAUSE, you can identify them by looking at pg\_aggregate
with the field aggkind that has been added to track that, with the
following types of aggregates defined:

  * 'n' for normal aggregates, like max, min, etc.
  * 'o' for the ordered-set aggregates
  * 'h' for the hypothetical-set aggregates, which are a subclass of
set-ordered aggregates

And here is their complete list:

    =# SELECT aggfnoid, aggkind
       FROM pg_aggregate
       WHERE aggkind IN ('o', 'h');
              aggfnoid          | aggkind
    ----------------------------+---------
     pg_catalog.percentile_disc | o
     pg_catalog.percentile_cont | o
     pg_catalog.percentile_cont | o
     pg_catalog.percentile_disc | o
     pg_catalog.percentile_cont | o
     pg_catalog.percentile_cont | o
     mode                       | o
     pg_catalog.rank            | h
     pg_catalog.percent_rank    | h
     pg_catalog.cume_dist       | h
     pg_catalog.dense_rank      | h
    (11 rows)

Continuing with the percentile aggregates, it is important to understand
the difference between percentile\_cont and percentile\_dist.

  * percentile\_disc returns an exact value, being the first value whose
position in the ordering equals or exceeds the specified fraction of
portion in the subset
  * percentile\_cont returns the value corresponding to the fraction
specified, interpolating with adjacent values if necessary.

Some with the previous examples, here is the result obtained for the
25th percentile for both percentile\_disc and percentile\_cont.

    =# SELECT percentile_disc(0.25) WITHIN GROUP (ORDER BY a) as inter_max,
              percentile_cont(0.25) WITHIN GROUP (ORDER BY a) as abs_max
       FROM aa;
     inter_max | abs_max
    -----------+---------
             5 |    5.75
    (1 row)

Now let's have a look at mode(), which chooses the most-frequent present
value in the subset. If multiple values are present equal times, the first
one in the subset is selected.

    =# SELECT mode() WITHIN GROUP (ORDER BY a) AS most_frequent FROM aa;
     most_frequent
    ---------------
                 1
    (1 row)

All the values are present only once in this case, but if we add a new
value in the table between 1 and 20 that will make it the most-frequently
present one, here is what we get:

    =# INSERT INTO aa VALUES (8);
    INSERT 0 1
    =# SELECT mode() WITHIN GROUP (ORDER BY a) AS most_frequent FROM aa;
     most_frequent
    ---------------
                 8
    (1 row)

And now a couple of words about the hypothetical-set aggregates that are
rank, percent\_rank, cume\_dist and dense_rank. rank can be used to fetch
the rank (Oh surprise!) of a given value in a subset with gaps for duplicated
values. With the previous example of table aa using 20 rows with one value,
actually "8" present twice, here is what you get.

    =# SELECT rank(8) WITHIN GROUP (ORDER BY a) FROM aa;
     rank
    ------
        8
    (1 row)
    =# SELECT rank(9) WITHIN GROUP (ORDER BY a) FROM aa;
     rank
    ------
       10
    (1 row)

Value "8" is ranked as 8, while value "9" is ranked as "10". Note as well
values not present in the subset can be used, their rank is adapted depending
on the other values. Here by for example removing "7".

    =# delete from aa where a = 7;
    DELETE 1
    =# SELECT rank(7) WITHIN GROUP (ORDER BY a) FROM aa;
     rank
    ------
        7
    (1 row)
    =# SELECT rank(8) WITHIN GROUP (ORDER BY a) FROM aa;
     rank
    ------
        7
    (1 row)
    =# SELECT rank(6) WITHIN GROUP (ORDER BY a) FROM aa;
     rank
    ------
        6
    (1 row)

dense\_rank works similarly, except that it uses no gaps. Finally
percent\_rank and cume\_dist work similarly. They can be used to get the
relative rank of a given value in the subset, the main difference
between those two functions being that percent\_rank ranges from 0 to 1,
while cume_dist ranges from 1/N to 1.

    =# SELECT cume_dist(1) WITHIN GROUP (ORDER BY a) as val_1,
              cume_dist(7) WITHIN GROUP (ORDER BY a) as val_7,
              cume_dist(8) WITHIN GROUP (ORDER BY a) as val_8,
              cume_dist(9) WITHIN GROUP (ORDER BY a) as val_9
       FROM aa;
           val_1        |       val_7       |       val_8       | val_9
    --------------------+-------------------+-------------------+-------
     0.0909090909090909 | 0.363636363636364 | 0.454545454545455 |   0.5
    (1 row)
    =# SELECT percent_rank(1) WITHIN GROUP (ORDER BY a) as val_1,
              percent_rank(7) WITHIN GROUP (ORDER BY a) as val_7,
              percent_rank(8) WITHIN GROUP (ORDER BY a) as val_8,
              percent_rank(9) WITHIN GROUP (ORDER BY a) as val_9
        FROM aa;
     val_1 |       val_7       |       val_8       |       val_9
    -------+-------------------+-------------------+-------------------
         0 | 0.285714285714286 | 0.333333333333333 | 0.428571428571429
    (1 row)

Note that there are 21 rows in the example table at this point. And I think
that this is all about ordered-set aggregates, enjoy simplifying your life
with Postgres 9.4!
