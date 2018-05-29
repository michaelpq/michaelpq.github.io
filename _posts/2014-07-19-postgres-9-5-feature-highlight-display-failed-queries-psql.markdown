---
author: Michael Paquier
lastmod: 2014-07-19
date: 2014-07-19 12:52:43+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-display-failed-queries-psql
title: 'Postgres 9.5 feature highlight - Display failed queries in psql'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.5
- error
- psql

---
Postgres 9.5 is coming up with a new ECHO mode for [psql]
(https://www.postgresql.org/docs/devel/static/app-psql.html) that has been
introduced by this commit:

    commit: 5b214c5dd1de37764797b3fb9164af3c885a7b86
    author: Fujii Masao <fujii@postgresql.org>
    date: Thu, 10 Jul 2014 14:27:54 +0900
    Add new ECHO mode 'errors' that displays only failed commands in psql.

    When the psql variable ECHO is set to 'errors', only failed SQL commands
    are printed to standard error output. Also this patch adds -b option
    into psql. This is equivalent to setting the variable ECHO to 'errors'.

    Pavel Stehule, reviewed by Fabrízio de Royes Mello, Samrat Revagade,
    Kumar Rajeev Rastogi, Abhijit Menon-Sen, and me.

Up to now, there have been two ECHO modes:

  * "all", to print to the standard output all the queries before they are
parsed or executed. This can be set when starting psql with option -a.
  * "queries", to have psql print all the queries sent to server. This can
be set additionally with option -e of psql.

The new mode is called "errors" and can be either set with the option -b
when starting psql or with "set" command in a psql client like that:

    =# \set ECHO errors

The feature added is simple: have psql print all the failed queries in the
standard error output. The failed query is printed in an additional field
prefixed with STATEMENT:

    =# CREATE TABLES po ();
    ERROR:  42601: syntax error at or near "TABLES"
    LINE 1: CREATE TABLES po ();
               ^
    LOCATION:  scanner_yyerror, scan.l:1053
    STATEMENT:  CREATE TABLES po ();

If multiple queries are specified within a single input only the query that
failed is displayed:

    =# CREATE TABLE aa (a int); CREATE FOO po; CREATE TABLE bb (a int);
    CREATE TABLE
    ERROR:  42601: syntax error at or near "FOO"
    LINE 1: CREATE FOO po;
                   ^
    LOCATION:  scanner_yyerror, scan.l:1053
    STATEMENT:  CREATE FOO po;
    CREATE TABLE

Also, queries that are typed in multiple lines are showed as they are,
spaces included:

    =# SELECT
          col1_not_here,
          col2_not_here
       FROM
          table_not_here;
    ERROR:  42P01: relation "table_not_here" does not exist
    LINE 5:     table_not_here;
                ^
    LOCATION:  parserOpenTable, parse_relation.c:986
    STATEMENT:  SELECT
        col1_not_here,
        col2_not_here
    FROM
        table_not_here;
