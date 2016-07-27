---
author: Michael Paquier
lastmod: 2016-07-27
date: 2016-07-27 13:14:54+00:00
layout: post
type: post
slug: postgres-9-6-behavior-change-pg-get
title: 'Postgres 9.6 - Upcoming changes for pg_get functions on invalid objects'
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
- behavior
- change
- detail
- object
- trigger

---

Today the following commit has landed on the master branch of PostgreSQL,
meaning that it will be included in the upcoming 9.6:

    commit: 976b24fb477464907737d28cdf18e202fa3b1a5b
    author: Robert Haas <rhaas@postgresql.org>
    date: Tue, 26 Jul 2016 16:07:02 -0400
    Change various deparsing functions to return NULL for invalid input.

    Previously, some functions returned various fixed strings and others
    failed with a cache lookup error.  Per discussion, standardize on
    returning NULL.  Although user-exposed "cache lookup failed" error
    messages might normally qualify for bug-fix treatment, no back-patch;
    the risk of breaking user code which is accustomed to the current
    behavior seems too high.

First note that the following functions are impacted by this change:

  * pg\_get\_constraintdef
  * pg\_get\_functiondef
  * pg\_get\_indexdef
  * pg\_get\_ruledef
  * pg\_get\_triggerdef
  * pg\_get\_viewdef

And that those functions could behave in quite strange ways when used with
an invalid object. Before this change, some of those functions complained
about a cache lookup error or similar which means that an internal error
happened, and users continuously ask for the meaning of such errors:

    =# SELECT pg_get_constraintdef(0);
    ERROR:  XX000: cache lookup failed for constraint 0
    LOCATION:  pg_get_constraintdef_worker, ruleutils.c:1377
    =# SELECT pg_get_functiondef(0);
    ERROR:  XX000: cache lookup failed for function 0
    LOCATION:  pg_get_functiondef, ruleutils.c:1958
    =# SELECT pg_get_indexdef(0);
    ERROR:  XX000: cache lookup failed for index 0
    LOCATION:  pg_get_indexdef_worker, ruleutils.c:1054
    =# SELECT pg_get_triggerdef(0);
    ERROR:  XX000: could not find tuple for trigger 0
    LOCATION:  pg_get_triggerdef_worker, ruleutils.c:762

And the other functions returned some inconsistent output:

    =# SELECT pg_get_ruledef(0);
     pg_get_ruledef
    ----------------
     -
    (1 row)
    =# SELECT pg_get_viewdef(0);
     pg_get_viewdef
    ----------------
     Not a view
    (1 row)

When used on catalog indexes things can get funny as mentioned
[here](https://www.postgresql.org/message-id/CAB7nPqThJsGnH2JNyHPZmXFk8a26RhqRhR7in0zCpT%2BOttfzEw%40mail.gmail.com):

    =# SELECT indexdef FROM pg_catalog.pg_indexes WHERE indexdef IS NOT NULL;
    ERROR:  XX000: cache lookup failed for index 2619
    LOCATION:  pg_get_indexdef_worker, ruleutils.c:1054

With the new behavior, what happens is that when an invalid object is
used, those functions return NULL, making the error handling at application
level more deterministic. More importantly, this is wanted a consistent
behavior across all the SQL-level functions having the role to show
to users object definitions:

    =# SELECT pg_get_ruledef(0);
     pg_get_ruledef
    ----------------
     null
    (1 row)

There are surely out there some applications that rely on those functions
behaving as they do currently, so when switching to 9.6 be careful with
modifications in this area. This change is surely for the best by the way,
work on catalog tables becomes far easier thanks to that.

Also, on top of the functions already mentioned, the following ones will
likely follow the same path by returning NULL on invalid objects:

  * pg\_get\_function\_arguments
  * pg\_get\_function\_identity\_arguments
  * pg\_get\_function\_result
  * pg\_get\_function\_arg\_default
