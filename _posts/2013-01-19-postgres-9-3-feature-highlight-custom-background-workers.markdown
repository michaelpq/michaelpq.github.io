---
author: Michael Paquier
comments: true
date: 2013-01-19 16:08:08+00:00
layout: post
slug: postgres-9-3-feature-highlight-custom-background-workers
title: 'Postgres 9.3 feature highlight: custom background workers'
wordpress_id: 1572
categories:
- PostgreSQL-2
tags:
- '9.3'
- background
- customize
- database
- feature
- highliht
- new
- open source
- pg
- postgres
- postgresql
- relational
- release
- spi
- worker
---

A new feature ideal for module makers is appearing in Postgres 9.3. Called "background worker processes", this feature, which is a set of useful APIs, offers the possibility to create and customize worker processes called bgworkers able to run user-specified code directly plugged in the server. This worker is loaded and managed entirely by the server. So such processes can be considered as envelopped in a wrapper on top of the core code as a plug-in.

This feature has been introduced by this commit.

    commit da07a1e856511dca59cbb1357616e26baa64428e
    Author: Alvaro Herrera <alvherre@alvh.no-ip.org>
    Date:   Thu Dec 6 14:57:52 2012 -0300

    Background worker processes

    Background workers are postmaster subprocesses that run arbitrary
    user-specified code.  They can request shared memory access as well as
    backend database connections; or they can just use plain libpq frontend
    database connections.

    Modules listed in shared_preload_libraries can register background
    workers in their _PG_init() function; this is early enough that it's not
    necessary to provide an extra GUC option, because the necessary extra
    resources can be allocated early on.  Modules can install more than one
    bgworker, if necessary.

    Care is taken that these extra processes do not interfere with other
    postmaster tasks: only one such process is started on each ServerLoop
    iteration.  This means a large number of them could be waiting to be
    started up and postmaster is still able to quickly service external
    connection requests.  Also, shutdown sequence should not be impacted by
    a worker process that's reasonably well behaved (i.e. promptly responds
    to termination signals.)

    The current implementation lets worker processes specify their start
    time, i.e. at what point in the server startup process they are to be
    started: right after postmaster start (in which case they mustn't ask
    for shared memory access), when consistent state has been reached
    (useful during recovery in a HOT standby server), or when recovery has
    terminated (i.e. when normal backends are allowed).

    In case of a bgworker crash, actions to take depend on registration
    data: if shared memory was requested, then all other connections are
    taken down (as well as other bgworkers), just like it were a regular
    backend crashing.  The bgworker itself is restarted, too, within a
    configurable timeframe (which can be configured to be never).

    More features to add to this framework can be imagined without much
    effort, and have been discussed, but this seems good enough as a useful
    unit already.

    An elementary sample module is supplied.

You can imagine many scenarios where your own customized workers would be useful, especially for maintainance tasks, and here are some examples:

  * Disconnect automatically idle connections on the server, with a combo of the type pg_stat_activity/pg_terminate_backend
  * Create customized statistic information
  * Save information related to the database
  * Monitor table indexes and reindex things that have been failing
  * Log extra information regarding the activity of the database

There are of course many other use cases possible...

By the way, in order to show how this feature works, I wrote a really simple example of a customized worker called count_relations that counts every second the number of relations in the database server and that outputs the result in the server logs. 

The code written uses as a base the example in contrib/worker_spi/ of Postgres tarball in a really simplified way. It is available for download [here](http://michael.otacoo.com/wp-content/uploads/2013/01/count_relations.tar.gz). 

After playing with this code, I also wanted to share my experience, so here are a couple of points you should take care of when writing your own customized worker.

#### Initialize and register the worker correctly

Postgres core uses _PG_init as an entry point to register the customized worker, so be sure to initialize your worker(s) in a way close to that:

    void
    _PG_init(void)
    {
        BackgroundWorker    worker;
        /* register the worker processes */
        worker.bgw_flags = BGWORKER_SHMEM_ACCESS |
        BGWORKER_BACKEND_DATABASE_CONNECTION;
        worker.bgw_start_time = BgWorkerStart_RecoveryFinished;
        worker.bgw_main = worker_spi_main;
        worker.bgw_sighup = worker_spi_sighup;
        worker.bgw_sigterm = worker_spi_sigterm;
        worker.bgw_name = "count relations";
        worker.bgw_restart_time = BGW_NEVER_RESTART;
        worker.bgw_main_arg = NULL;
       RegisterBackgroundWorker(&worker;);
    }

#### Respect the transaction flow

Inside a worker, queries are run through the SPI, so be sure to respect a transaction flow similar to that:

    StartTransactionCommand(); // start transaction
    SPI_connect(); // start the SPI
    PushActiveSnapshot(GetTransactionSnapshot());
    [ ... ] // build query
    SPI_execute(query, true/false, 0); //true for read-only, false for read-write
    [ ... ] // result treatment
    SPI_finish(); // finish SPI
    PopActiveSnapshot(); // throw snapshot
    CommitTransactionCommand(); // commit transaction

#### Make a simple makefile

The makefile does not need to be that complicated, something like that is sufficient:

    MODULES = count_relations
    PG_CONFIG = pg_config
    PGXS := $(shell $(PG_CONFIG) --pgxs)
    include $(PGXS)

In order to install this module correctly, be sure that LD_LIBRARY_PATH is points to the folder where the libraries of postgres are installed, then only do a "make install" and you are done.

#### Set up server and load your library

Before starting your server, you need to set up shared_preload_libraries in postgresql.conf to the name of your customized libraries to have them uploaded at start-up. In the case of count_relations, it consists in adding that:

    shared_preload_libraries = 'count_relations'

#### Check worker start

All the workers are called "bgworker: $NAME", depending on the name you chose for your module.
In the case of count_relations:

    ps x | grep bgworker
    25146 ? Ss 0:00 postgres: bgworker: count relations

Then, for count_relations, you can also have a look at the logs of the server and you will see lines of that type, proving that the bgworker is working correctly.

    LOG:  Currently 292 relations in database`

#### Rely on the worker_spi example

When writing a new worker, try not to write it from scratch but use as a base the code of worker_spi. This code already implements some methods that can be used generically like signal handling, latch management and database connection. So use it and abuse of it!

As a last word, it is important to understand that the example of bgworker made for this post is really basic, and touches only a tiny portion of what is available in the feature APIs, so be sure to have a look at the [documentation](http://www.postgresql.org/docs/devel/static/bgworker.html) for further details.
