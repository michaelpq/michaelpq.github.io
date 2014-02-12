---
author: Michael Paquier
comments: true
date: 2014-02-12 21:21:12+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-with-ordinality
title: 'Postgres 9.4 feature highlight: WITH ORDINALITY'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.4
- feature
- highlight
- with
- ordinality
- sql
- set
- returning
- function
- row
- tuple
- ordering
- unnest
- array
---
PostgreSQL 9.4 is going to be shipped with a feature of the SQL standard called [WITH ORDINALITY](http://www.postgresql.org/docs/devel/static/functions-srf.html). It has been introduced by this commit:

    commit c62736cc37f6812d1ebb41ea5a86ffe60564a1f0
    Author: Greg Stark <stark@mit.edu>
    Date:   Mon Jul 29 16:38:01 2013 +0100

    Add SQL Standard WITH ORDINALITY support for UNNEST (and any other SRF)
    
    Author: Andrew Gierth, David Fetter
    Reviewers: Dean Rasheed, Jeevan Chalke, Stephen Frost

When those keywords are appended after a function returning a set of rows in a FROM clause, an additional bigint column is added in the result, containing a counter beginning at 1 and incremented for each row returned by the function. [The original commit implementing unnest()](http://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=c889ebce0aa5f848d680547e3af0aad8b9e577a7) actually missed this feature, so that's a great addition.

Here is how it works with a simple function returning rows.

    =# SELECT * FROM generate_series(4,1,-1) WITH ORDINALITY;
     generate_series | ordinality 
    -----------------+------------
                   4 |          1
                   3 |          2
                   2 |          3
                   1 |          4
    (4 rows)

The default column name is called "ordinality", but it is possible to associate an alias to it, like that for example:

    =# SELECT * FROM json_object_keys('\{"a1":"1","a2":"2","a3":"3"\}')
       WITH ORDINALITY AS t(keys, n);
     keys | n 
    ------+---
     a1   | 1
     a2   | 2
     a3   | 3
    (3 rows)

This feature is actually pretty useful when used with arrays when decomposing them with unnest().

    =# SELECT * from unnest('\{\{14,41,7\},\{54,9,49\}\}'::int[])
       WITH ORDINALITY AS t(elts, num);
     elts | num 
    ------+-----
       14 |   1
       41 |   2
        7 |   3
       54 |   4
        9 |   5
       49 |   6
    (6 rows)

And it is actually far more interesting with the new feature called [ROWS FROM](http://michael.otacoo.com/postgresql-2/postgres-9-4-feature-highlight-multi-argument-unnest-and-table-for-multiple-functions/) (or multi-argument unnest), because you can associate a counter usable for some ORDER BY operations easily with that.

    =# SELECT * FROM unnest('\{1,2,3\}'::int[], '\{4,5,6,7\}'::int[])
       WITH ORDINALITY AS t(a1, a2, num) ORDER BY t.num DESC;
      a1  | a2 | num 
    ------+----+-----
     null |  7 |   4
        3 |  6 |   3
        2 |  5 |   2
        1 |  4 |   1
    (4 rows)

Original, no?
