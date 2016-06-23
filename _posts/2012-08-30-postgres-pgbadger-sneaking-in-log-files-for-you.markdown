---
author: Michael Paquier
lastmod: 2012-08-30
date: 2012-08-30 05:47:10+00:00
layout: post
type: post
slug: postgres-pgbadger-sneaking-in-log-files-for-you
title: 'Postgres - pgbadger sneaking in log files for you'
categories:
- PostgreSQL-2
tags:
- analyze
- database
- deparse
- file
- html
- info
- log
- module
- perl
- pgbadger
- pgfouine
- php
- postgres
- postgresql
- statement
- statistics
---

[pgbadger](http://github.com/dalibo/pgbadger) is a recent Postgres module presented during the lightning talks of PGCon 2012 by its original author Gilles Darold. It is thought as an alternative to [PgFouine](http://pgfouine.projects.postgresql.org/), able to replace it thanks to its flexibility, extensibility and performance.

So, like PGFouine, pgbadger is a Postgres log file analyzer, meaning that it is able to deparse, analyze the data of your log files and then provide statistics about your database: from overall data (query list, number of transactions), error counts (most frequent events) to more performance details like the queries that took the longest run time.
This means that basically you use in input log files from PostgreSQL, and you get in output an html or txt page that gives you all the statistics you want. So you do not need to sneak anymore in your log files to analyze what is happening anymore. Simply launch pgbadger, wait for parsing (which is pretty fast btw), and see.

Before describing more in details the functionalities of pgbadger, why is it an alternative to pgfouine?
	
  1. pgbadger is written in perl, pgfouine is written in php. So with pgbadger you do not need to install extra packages, Postgres core using natively perl. And well, perl is more performant than php. And php... is php...
  2. Developped by the community, for the community
  3. Latest release of pgfouine is from 2010, it doesn't look to be that much maintained. pgbadger is a new project, young and dynamic, and more and more people are gathering to develop it.
  4. It is developed by cool guys, OK pgfouine also... That is maybe not a real argument...

Now, let's put our hands on the beast. There are several ways to get this module.
First, you can fetch the code of the project directly from Github with those commands:

    git clone https://github.com/dalibo/pgbadger.git

Also, you can download the tarball from [here](https://github.com/dalibo/pgbadger/downloads).
Then install it with those commands.

    tar xzf pgbadger-1.x.tar.gz
    cd pgbadger-1.x/
    perl Makefile.PL
    make && sudo make install

This will install pgbadger in /usr/bin/local and some man pages. You can refer to the README of the project for more details.

As told before, pgbadger is a log file deparser, so you need to set up the output of your log files correctly to allow pgbadger to look at your database server information. The more logging parameters you activate, the more information you will be able to get from your log files. Here are the settings I used for this post and the test below.

    logging_collector = on
    log_min_messages = debug1
    log_min_error_statement = debug1
    log_min_duration_statement = 0
    log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d '
    log_checkpoints = on
    log_connections = on
    log_disconnections = on
    log_lock_waits = on
    log_temp_files = 0

You will need to customize those options depending on the information you want, just do not forget that setting up the root correctly is the key for success.
At the state of pgbadger 2.0, log\_statement and log\_duration cannot be activated, so take care not to use them.

For the purpose of this post and in order to produce a couple of log files, I ran a 5-minute pgbench test on a fresh Postgres server.
So the logs I obtained are not at all production-like, but enough to show what pgbadger can do.

By the way, pgbadger has several options making it pretty flexible, among them you have the possibility to specify multiple log files at the same time, specify an interval of time for the analysis, and far more. It is also possible to choose output format of result. Among the possible use cases I got on top of my head:
	
  * Creation of a text file report, and send it to a mailing list automatically	
  * Creation of an html file, and upload it automatically to a web server
  * Base log analysis on a cron with a certain time interval
  * etc.

pgbadger has few dependencies, so it makes it pretty flexible for your environments. Once again the README of the project gives more examples of use, so do not hesitate to refer to it.

So, just after my short pgbench run, I got a set of log files ready for analysis. Now it is time to parse them.
Note: the pgbench test has been done with default values without thinking, so don't worry about the bad performance results :)

    $ ./pgbadger ~/pgsql/master/pg_log/postgresql-2012-08-30_132* 
    [========================>] Parsed 10485768 bytes of 10485768 (100.00%)
    [========================>] Parsed 10485828 bytes of 10485828 (100.00%)
    [========================>] Parsed 10485851 bytes of 10485851 (100.00%)
    [========================>] Parsed 10485848 bytes of 10485848 (100.00%)
    [========================>] Parsed 10485839 bytes of 10485839 (100.00%)
    [========================>] Parsed 982536 bytes of 982536 (100.00%)

In result, I got a file called out.html (default, but customizable) showing a bunch of data, analyzing things automatically.
The most interesting part is perhaps the performance analysis, showing you a list of the less performant queries, so this will allow you to tune your database based on the log data obtained.

So, pgbadger is light, fast and is waiting for your love. It is one of those utilities that you can use not only for production database systems, but for extra things like benchmark or performance analysis. Its installation is easy, will not heavy your system with packages you might not want, so go ahead and use it.

