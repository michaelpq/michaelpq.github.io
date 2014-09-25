---
author: Michael Paquier
comments: true
lastmod: 2013-07-22
date: 2013-07-22 00:51:54+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-refresh-concurrently-a-materialized-view
title: 'Postgres 9.4 feature highlight: REFRESH CONCURRENTLY a materialized view'
categories:
- PostgreSQL-2
tags:
- '9.4'
- awesome
- concurrently
- database
- development
- incremental
- materialized view
- open source
- postgres
- postgresql
- refresh
---

Postgres 9.3 has introduced the first features related to [materialized views](/postgresql-2/postgres-9-3-feature-highlight-materialized-views/). The upcoming version of Postgres is adding many basic things like the possibility to create, manage and refresh a materialized views. However, materialized views in Postgres 9.3 have a severe limitation consisting in using an exclusive lock when refreshing it. This basically blocks any attempts to read a materialized view while it is being refreshed with new data from its parent relations, which is particularly a handicap for large materialized views on production servers.

While Postgres 9.3 will normally come out in Autumn and is currently in beta, 9.4 is already in development and the issue of a too strong lock taken when refreshing a materialized view has been solved by adding a new feature allowing to refresh it concurrently. This simply allows to read from a materialized view while it is being refreshed with a lower lock.

    commit cc1965a99bf87005f431804bbda0f723887a04d6
    Author: Kevin Grittner <kgrittn@postgresql.org>
    Date:   Tue Jul 16 12:55:44 2013 -0500
    
    Add support for REFRESH MATERIALIZED VIEW CONCURRENTLY.
    
    This allows reads to continue without any blocking while a REFRESH
    runs.  The new data appears atomically as part of transaction
    commit.
    
    Review questioned the Assert that a matview was not a system
    relation.  This will be addressed separately.
    
    Reviewed by Hitoshi Harada, Robert Haas, Andres Freund.
    Merged after review with security patch f3ab5d4.

When running a CONCURRENT operation, the possibility to run read query on a materialized view is traded with a higher resource consumption and a longer time necessary to complete the view refresh process. Now let's have a look at it more deeply.

First, REFRESH CONCURRENTLY can only be run if the involved materialized view has at least one unique index.

    postgres=# CREATE TABLE aa AS SELECT generate_series(1,1000000) AS a;
    SELECT 1000000
    postgres=# CREATE MATERIALIZED VIEW aam AS SELECT * FROM aa;
    SELECT 1000000
    postgres=# REFRESH MATERIALIZED VIEW CONCURRENTLY aam ;
    ERROR:  55000: cannot refresh materialized view "public.aam" concurrently
    HINT:  Create a UNIQUE index with no WHERE clause on one or more columns of the materialized view.
    postgres=# CREATE UNIQUE INDEX aami ON aam(a);
    CREATE INDEX
    postgres=# REFRESH MATERIALIZED VIEW CONCURRENTLY aam;
    REFRESH MATERIALIZED VIEW

While the refresh was running, reading from the materialized view worked, of course, as expected, and I did not notice any performance impact.

The unique index used also cannot include any WHERE clauses, or index on any expressions.

    postgres=# DROP INDEX aami;
    DROP INDEX
    postgres=# CREATE UNIQUE INDEX aami ON aam(a) where a < 50000;
    CREATE INDEX
    postgres=# REFRESH MATERIALIZED VIEW CONCURRENTLY aam ;
    ERROR:  55000: cannot refresh materialized view "public.aam" concurrently
    HINT:  Create a UNIQUE index with no WHERE clause on one or more columns of the materialized view.
    LOCATION:  refresh_by_match_merge, matview.c:691

After some testing, it looks that REFRESH can take quite a bit of time to return an error back to client when not finding a unique index necessary to complete the refresh operation. I am personally wondering why this takes so long...

However, having such a command available is really a nice thing and it is great that Kevin Grittner took the time to implement it for the first commit fest of 9.4, as it removes one of the main barriers materialized views are facing in Postgres 9.3 with applications using materialized views mainly for cache-related purposes.
