---
author: Michael Paquier
comments: true
lastmod: 2011-03-22
date: 2011-03-22 18:25:19+00:00
layout: post
type: post
slug: about-regression-tests-for-postgres-xc-pg_regress
title: 'About regression tests for Postgres-XC: pg_regress'
wordpress_id: 275
categories:
- PostgreSQL-2
tags:
- check
- cluster
- command
- default
- install
- pg_regress
- port
- postgres-xc
- postgresql
- regression
- test
---

pg\_regress is a PostgreSQL test module that permits to check if you have done correctly an installation of a PostgreSQL server.

Until now, the development of Postgres-XC has been focused on scalability and performance, without always checking if implementation sticked with PostgreSQL standards.
However, in order to be able to consider Postgres-XC as a product, it has to pass those regression tests.
This is also the easiest way to check if it respects the SQL rules protected by PostgreSQL, making it a user-friendly software.

So, why passing regression tests?

  1. Prove that XC can be stable
  2. Improve efficiency of the implementation of new functionalities. All the SQL test cases are already in the regression tests, so checking if an implementation is correct is faster and secured. Passing also regression tests makes the basics of Postgres-XC really stronger.

Well, are those regression tests sufficient?
No, they are a base to protect the basics of the cluster product when running SQL queries. As a cluster, Postgres-XC needs tests for:

  1. High-availability (node failure, security)
  2. performance (write-scalability)
  3. regression tests specific to Postgres-XC (CREATE TABLE has been extended with DISTRIBUTE BY [REPLICATION | HASH(column) | ROUNDROBIN | MODULO(column)])

Let's talk a little bit more about pg\_regress.

All its files are located in src/test/regress.
The most common usage made is an installation check, what would basically consist in typing the following command in src/test/regress:

    make installcheck

This command allows to launch regression tests on a PostgreSQL server having the default port 5432 open.

    ./pg_regress --inputdir=. --dlpath=. --multibyte=SQL_ASCII  --psqldir=$HOME/pgsql/bin --schedule=./serial_schedule

Let's have a look at what makes pg\_regress... You can find the following folders:

  * data, all the external data used for mainly COPY
  * input, input data for SQL queries that depend on the environment where regression tests are launched: COPY, TABLESPACE... Those files have the suffix .source, and are saved in folder sql after generation
  * output, output files whose content are modified depending on the environment where regressions are installed
  * expected, all the expected results. Those files have the prefix .out and have the same prefix name as the sql or source files
  * sql, all the files containing the SQL queries to run for regression tests. They have the same prefix name as the corresponding expected result files .out.

For Postgres-XC, as the default table type is round robin, or hash if the first column can be distributed, the order of output data for SELECT queries cannot be controlled.
As regressions have to give the same results whatever the cluster configuration (it cannot depend on the number of Coordinators and Datanodes), SELECT queries are sometimes completed with ORDER BY.
For some types where ORDER BY has no effect like box or point, the table is created as a replicated one (use of keyword DISTRIBUTE BY REPLICATION at the end of CREATE TABLE).

There are 121 test cases that have to be checked in pg\_regress.
Most of them can be corrected based on the current limitations of Postgres-XC (update, delete, case, guc...).
But some of them require more fundamental work (select\_having, subselect, returning).
Others are currently making the cluster entering in a stall state (errors, constraints).

This is a huge task. But once this is completed,
Postgres-XC will have the base that will make it a great cluster product!
