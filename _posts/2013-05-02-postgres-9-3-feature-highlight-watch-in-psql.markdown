---
author: Michael Paquier
comments: true
lastmod: 2013-05-02
date: 2013-05-02 05:01:04+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-watch-in-psql
title: 'Postgres 9.3 feature highlight: \watch in psql'
categories:
- PostgreSQL-2
tags:
- '9.3'
- client
- database
- interval
- open source
- postgres
- postgresql
- psql
- query
- relational
- repeat
- time
- watch
---

psql is the native client of PostgreSQL widely used by application developers and database administrators on a daily-basis for common operations when interacting with a PostgreSQL server. With a full set of integrated functionalities, it is among the most popular (if not the number one) client applications in the Postgres community. If you are a Postgres nerd (highly possible if you are reading this page), you know that the feeling of discovering a new functionality in psql is close to the excitement you can have when opening a christmas present as you know that such a feature went though the strict community review process. The upcoming release 9.3 of Postgres is not an exception and brings a new useful command called [\watch](http://www.postgresql.org/docs/devel/static/app-psql.html). This feature has been introduced by this commit:

    commit c6a3fce7dd4dae6e1a005e5b09cdd7c1d7f9c4f4
    Author: Tom Lane <tgl@sss.pgh.pa.us>
    Date:   Thu Apr 4 19:56:33 2013 -0400
    
    Add \watch [SEC] command to psql.
    
    This allows convenient re-execution of commands.
    
    Will Leinweber, reviewed by Peter Eisentraut, Daniel Farina, and Tom Lane

Close to what \g can do when replaying the last query stored in buffer, \watch offers the possibility to replay the same query with a given interval of time as follows:

    \watch [ seconds ]

Compared to a wrapper on psql that would run repetitively the same query, \watch does not need to acquire a new connection each time the query is executed, saving some execution overhead. Also, the watch automatically stops if a failure occurs for the query.

Note that \watch can only be used at the end of the query you want to run.

    postgres=# \watch 2 "SELECT 1"

\watch cannot be used with an empty query

This error does not appear if a query is stored in buffer.

If no query is specified it will use the latest query in buffer.

    postgres=# \watch 10
    Watch every 10s	Thu May  2 13:15:14 2013
    
     ?column? 
    ----------
            1
    (1 row)

For example, simply check if your server is alive using psql:

    postgres=# select 1; \watch 1
     ?column? 
    ----------
            1
    (1 row)
    Watch every 1s	Thu May  2 13:06:53 2013
        
     ?column? 
    ----------
            1
    (1 row)
    
    server closed the connection unexpectedly
    This probably means the server terminated abnormally
     before or while processing the request.
    The connection to the server was lost. Attempting reset: Succeeded.

Oops, the connection has been closed...

Here is an other example: check every minute the latest query that ran on server.

    postgres=# SELECT datname, query, usename FROM pg_stat_activity ORDER BY query_start DESC LIMIT 1; \watch 60
     datname  |                                          query                                          | usename 
    ----------+-----------------------------------------------------------------------------------------+----------
     postgres | SELECT datname, query, usename FROM pg_stat_activity ORDER BY query_start DESC LIMIT 1; | postgres
    (1 row)
    
                                       Watch every 60s	Thu May  2 13:40:49 2013
    
     datname  |                                          query                                          | usename 
    ----------+-----------------------------------------------------------------------------------------+----------
     postgres | SELECT datname, query, usename FROM pg_stat_activity ORDER BY query_start DESC LIMIT 1; | postgres
    (1 row)

A last example: kill periodically backends (here every 60s) that have not been activated for a given period of time (here 30s).

    postgres=# SELECT pg_terminate_backend(pid) as status FROM pg_stat_activity
    postgres=# WHERE now() - state_change > interval '30 s' AND
    postgres=# pid != pg_backend_pid();
     status 
    --------
    (0 rows)
    
    postgres=# \watch 60
    Watch every 60s	Thu May  2 13:51:04 2013
    
     status 
    --------
    (0 rows)

In short, a lot of things are doable with \watch, you can automatize for example actions easily with a psql client, like the refresh of a materialized view. At least I won't need anymore to type 50 times the same query when developing an application using Postgres or creating a new feature.
