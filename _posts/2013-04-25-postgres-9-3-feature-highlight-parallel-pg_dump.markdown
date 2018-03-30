---
author: Michael Paquier
lastmod: 2013-04-25
date: 2013-04-25 00:01:43+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-parallel-pg_dump
title: 'Postgres 9.3 feature highlight - parallel pg_dump'
categories:
- PostgreSQL-2
tags:
- 9.3
- parallel
- pg_dump
- postgres
- postgresql

---

Among one of the many new features implemented in 9.3, pg\_dump now offers the possibility to perform parallel dumps. This feature has been introduced by the commit below.

    commit 9e257a181cc1dc5e19eb5d770ce09cc98f470f5f
    Author: Andrew Dunstan <andrew@dunslane.net>
    Date:   Sun Mar 24 11:27:20 2013 -0400
    
    Add parallel pg_dump option.
    
    New infrastructure is added which creates a set number of workers
    (threads on Windows, forked processes on Unix). Jobs are then
    handed out to these workers by the master process as needed.
    pg_restore is adjusted to use this new infrastructure in place of the
    old setup which created a new worker for each step on the fly. Parallel
    dumps acquire a snapshot clone in order to stay consistent, if
    available.
    
    The parallel option is selected by the -j / --jobs command line
    parameter of pg_dump.
    
    Joachim Wieland, lightly editorialized by Andrew Dunstan

This is an extremely nice improvement of pg\_dump as it allows accelerating the speed a dump is taken, particularly for machines having multiple cores as the load can be shared among separate threads.

Note that this option only works with the format called directoyy that can be specified with option -Fd or --format=directory, which outputs the database dump as a directory-format archive. A new option -j/--jobs can also be used to define the number of jobs that will run in parallel when performing the dump.

When using parallel pg\_dump, it is important to remember that n+1 connections are opened to the server, n being the number of jobs defined, with an extra master connection to control the shared locks taken on the objects dumped. So be sure that max\_connections is set up to a number high enough in accordance to the number of jobs that are planned.

Thanks to synchronized snapshots shared among the backends managed by the jobs, the dump is taken consistently ensuring that all the jobs share the same data view. However, as synchronized snapshots are only available since PostgreSQL 9.2, you need to be sure that no external sessions are doing any DML or DDL when performing a dump on servers whose version is lower than 9.2. It is also necessary to specify the option --no-synchronized-snapshots in this case.

Now, using a server having 16 cores, let's check how this feature performs. For this test, the schema of the database dumped is extremely simple: 16 tables with a constant size of approximately 200MB each (5000000 rows with a single int4 column), for a database having a total size of 3.2GB. Tests are conducted with 1, 2, 4, 8 and 16 jobs, so in the case of 16 jobs one table would be dumped by a unique job running on a single connection. This is of course an unrealistic schema for a production database, but here the point is to give an idea of how this feature can speed up a dump in an ideal case. 5 successive runs are done for each case.

Each test case has been run with the following command:

    time pg_dump -Fd -f $DUMP_DIRECTORY -j $NUM_JOBS $DATABASE_NAME

Jobs - Runs(s) | 1 | 2 | 3 | 4 | 5 | Avg
---------------|---|---|---|---|---|----
1 | 56.714 | 54.385 | 54.242 | 59.300 | 57.705 | 56.47
2 | 27.023 | 26.207 | 27.211 | 26.112 | 25.206 | 26.35
4 | 12.641 | 12.797 | 12.484 | 12.604 | 12.486 | 12.60
8 | 7.641 | 7.013 | 7.913 | 7.081 | 6.702 | 6.27
16 | 5.086 | 5.045 | 5.079 | 5.216 | 5.054 | 5.10

As expected, dump time is halved each time job number is doubled with this ideal database schema. However, due to some I/O disk bottleneck, the time gain is not that important with a high number of jobs. For example, in those series of tests, there is not much difference between 8 and 16 jobs, so be always aware of the I/O your dump disk can manage at most and choose carefully the number of jobs used for dumps based on that.
