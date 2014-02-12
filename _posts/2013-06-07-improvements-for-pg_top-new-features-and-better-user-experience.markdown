---
author: Michael Paquier
comments: true
date: 2013-06-07 04:00:18+00:00
layout: post
type: post
slug: improvements-for-pg_top-new-features-and-better-user-experience
title: 'Improvements for pg_top: new features and better user experience'
wordpress_id: 1960
categories:
- PostgreSQL-2
tags:
- activity
- database
- disk
- improve
- io
- monitor
- open source
- pgdata
- pg_top
- postgres
- postgresql
- top
- tps
- transaction
---

pg\_top is a monitoring tool designed for PostgreSQL in a way similar to top. When using it you can get a grab at the process activity of your server with an output similar to that:

    last pid:   425;  load avg:  0.07,  0.03,  0.02;       up 0+00:52:08                                                                                             12:22:02
    1 processes: 1 sleeping
    CPU states:  0.5% user,  0.0% nice,  0.1% system, 99.8% idle,  0.0% iowait
    Memory: 581M used, 15G free, 18M buffers, 211M cached
    Swap: 
    
    PID USERNAME PRI NICE  SIZE   RES STATE   TIME   WCPU    CPU COMMAND
    426 postgres  20    0  171M 5388K sleep   0:00  0.00%  0.00% postgres: postgres postgres [local] idle

The project has a dedicated GIT repository on [postgresql.org](http://git.postgresql.org/gitweb/?p=pg_top.git;a=summary) as well as a mirror on [github](https://github.com/markwkm/pg_top). There is also a [mailing list](http://lists.pgfoundry.org/mailman/listinfo/ptop-hackers) on pgfoundry dedicated to the project.

It has many customization options:

  * Connection to a given PostgreSQL server with a certain IP, port, username, etc.
  * Possibility to monitor server from remote
  * An interactive mode with the possibility change the output script or even to kill a list of processes

pg\_top supports many OSes (OSX, Linux, FreeBSD, hpux, aix). It is designed with a structure such as there is one set of generic APIs designed to get results for different purposes (process-related information mainly), the same function being written multiple times for each different OS but with the same spec. It is then decided which file to include in compilation at configure step by choosing among files named as machine/m\_$OS\_NAME.c.

These days I have been working on improving the user experience with pg\_top, [the first patch I sent](http://lists.pgfoundry.org/pipermail/ptop-hackers/2013-June/000195.html) consisting in improving a bit the documentation, the help message when an incorrect option is used and add support for long options. This was just based on my first impressions with this module, that looks to be powerful but difficult to apprehend for a newcomer.

However, the plan is not really to stop to that... Based on some optimizations added in the vPostgres version of pg\_top, a couple of extra features have been [proposed](http://lists.pgfoundry.org/pipermail/ptop-hackers/2013-June/000196.html).

#### 1. Database activity

The idea here is to query pg\_stat\_database and get back raw statistics based on transactions committed, rollbacked, tuples inserted, etc. Then those fields are analyzed and recompiled based on the time diff between two displays to get some TPS values. This is platform-independent as it relies entirely on pg\_stat\_database and libpq, so a generic function available to all the OS supported would be fine. The output could look like that:

    Activity: 1 tps, 0 rollbs/s, 0 buffer r/s, 100 hit%, 42 row r/s, 0 row w/s

#### 2. Disk space of PGDATA

Here, the plan is to get the disk space available for the partition where data folder of server is located, similarly to the output you can get with a plain df command. The result would look like that:

    PGDATA disk: 48.6 GB total, 14.2 GB free

This would be OS-dependent, so an additional type of API in the set dedicated to the machine/* files would be necessary, and return an error if this is not supported for a certain OS.

#### 3. Disk I/O

In order to do that, it is necessary to gather statistics from for example the parsing of a file like /proc/diskstats. The output could look like that:

    Disk I/O: 0 reads/s, 0 KB/s, 0 writes/s, 32 KB/s

Once again this is OS-dependent, so it would need an extra generic API.

All of those additional outputs could be printed to screen using some dedicated options, making the default the layer the same as the current one.

And you, do you have other ideas about what could be added in pg\_top?
