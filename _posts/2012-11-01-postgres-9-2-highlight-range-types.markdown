---
author: Michael Paquier
lastmod: 2012-11-01
date: 2012-11-01 08:19:10+00:00
layout: post
type: post
slug: postgres-9-2-highlight-range-types
title: 'Postgres 9.2 highlight: range types'
categories:
- PostgreSQL-2
tags:
- 9.2 open source
- bound
- data
- database
- empty
- feature
- infinite
- interval
- lower
- postgres
- postgresql
- range
- type
- upper
---

One of the new features introduced by PostgreSQL 9.2 is called [range types](http://www.postgresql.org/docs/9.2/static/rangetypes.html), which is, as you could easily guess based on this feature name, the possibility to use a range of values directly as a table column.

This simple feature allows your applications to avoid having a table using multiple columns to define start and end values of a range interval, one of the most intuitive examples being something like this:

    postgres# CREATE TABLE salary_grid (id int, position_name text, start_salary int, end_salary int);
    CREATE TABLE
    postgres# INSERT INTO salary_grid VALUES (1, 'junior developer', 20000, 30000);
    INSERT 0 1
    postgres# INSERT INTO salary_grid VALUES (2, 'senior developer', 28000, 35000);
    INSERT 0 1
    postgres# INSERT INTO salary_grid VALUES (3, 'postgres developer', 50000, 70000);
    INSERT 0 1

This simple relation is used to store for a given position level the range of salaries that are possible within a company (You can decide yourself the money unit of the salaries). The important point being that you would need to implement some system functions or some external application APIs to perform operations like intersection or union of the range, or simply define an exclude of one of the endpoints of the range interval.

Postgres 9.2 allows your application to rely directly on the database server to implement value intervals, the default value range types available being:
	
  * 4-byte integer range, int4range	
  * 8-byte integer range, int8range
  * numeric range, numrange
  * range of timestamp without timezone, tsrange
  * range of timestamp with timezone, tstzrange
  * range of date, daterange

You can also create your own range types. The Postgres documentation gives an example with [float](http://www.postgresql.org/docs/9.2/static/rangetypes.html#RANGETYPES-DEFINING):

    postgres# CREATE TYPE floatrange AS RANGE (
    postgres#    subtype = float8,
    postgres#    subtype_diff = float8mi);

With such a functionality, the previous example of the salary grid based on employee title levels becomes:

    postgres=# create table salary_grid (id int, position_name text, salary_range int4range);
    CREATE TABLE
    postgres=# INSERT INTO salary_grid VALUES (1, 'junior developer', '[20000, 30000]');
    INSERT 0 1
    postgres=# INSERT INTO salary_grid VALUES (2, 'senior developer', '[28000, 35000]');
    INSERT 0 1
    postgres=# INSERT INTO salary_grid VALUES (3, 'postgres developer', '[50000, 70000]');
    INSERT 0 1
    postgres=# select * from salary_grid;
     id |    position_name    | salary_range  
    ----+---------------------+---------------
      1 | junior developer   | [20000,30001)
      2 | senior developer   | [28000,35001)
      3 | postgres developer | [50000,70001)
    (3 rows)

It is important to notice that the tuple is stored with the upper bound excluded from the range, this is symbolyzed by the use of a parenthesis, a square bracket being used when the endpoint is included in the range.

There are also different functionalities possible directly inside core.
You can get directly the lower and upper bounds of a given range with the functions lower and upper.

    postgres=# SELECT upper(salary_range), lower(salary_range) FROM salary_grid;
     upper | lower 
    -------+-------
     30001 | 20000
     35001 | 28000
     70001 | 50000
    (3 rows)

You can check if a given value is included.

    postgres=# SELECT salary_range @> 4000 as check 
    postgres=# FROM salary_grid
    postgres=# WHERE position_name = 'junior developer';
     check 
    -------
     f
    (1 row)

Here 4000 is not included in the range of the junior position salary being [20000,30000].

A little bit more complicated here, but you can also check if salary ranges are overlapping between positions by using a function of the type $TYPErange, here the type of salary_range is int4, so the function called int4range is used for this operation.

    postgres=# WITH junior_salary AS (
    SELECT salary_range as junior
    FROM salary_grid
    WHERE position_name = 'junior developer'), 
    senior_salary AS (
    SELECT salary_range as senior
    FROM salary_grid
    WHERE position_name = 'senior developer')
    SELECT int4range(junior) && int4range(senior)  as check
    FROM junior_salary, senior_salary;
     check 
    -------
     t
    (1 row)

Here for example the salary range of junior and senior position overlap, this won't be possible with the postgres developer position for example.

You can also use infinite range values by not defining either an upper or lower bound value. You are also free to have both infinite values for lower and upper bounds. Let's take an extremely realistic example here:

    postgres# UPDATE salary_grid SET salary_range = '[50000,)'
              WHERE position_name = 'postgres developer';
    UPDATE 0 1
    postgres=# SELECT salary_range @> 60000000 as check
               FROM salary_grid WHERE position_name = 'postgres developer';
     check 
    -------
     t
    (1 row)

You can also use the functions lower\_inf or upper\_inf to check the infinity of a range.

There are other built-in functions already implemented in core (isempty, etc.), so be sure to have a look at the documentation of Postgres for more information.
This is all for this short introduction of range types.
