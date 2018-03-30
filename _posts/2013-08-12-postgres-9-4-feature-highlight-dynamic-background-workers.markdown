---
author: Michael Paquier
lastmod: 2013-08-12
date: 2013-08-12 07:54:18+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-dynamic-background-workers
title: 'Postgres 9.4 feature highlight - dynamic background workers'
categories:
- PostgreSQL-2
tags:
- 9.4
- postgres
- postgresql
- background
- worker

---
Following the [recent API modifications](/postgresql-2/modifications-of-apis-for-bgworkers-in-postgres-9-3/) done in Postgres 9.3 for background worker processes, here is more information about the latest features of background workers currently being developed for Postgres 9.4, and introduced by this commit:

    commit 7f7485a0cde92aa4ba235a1ffe4dda0ca0b6cc9a
    Author: Robert Haas
    Date: Tue Jul 16 13:02:15 2013 -0400
 
    Allow background workers to be started dynamically.
 
    There is a new API, RegisterDynamicBackgroundWorker, which allows
    an ordinary user backend to register a new background writer during
    normal running. This means that it's no longer necessary for all
    background workers to be registered during processing of
    shared_preload_libraries, although the option of registering workers
    at that time remains available.

The possibility to start background workers at will is a necessary condition for more complex features like parallel query processing. In this case a given server backend processing a read query with a huge ORDER BY could balance the execution load among multiple CPUs used other slave backends, or workers, started dynamically to accelerate the operation. Starting and stopping backends would be in this case in charge of the master backend at the execution level, while the number of backends to use would need to be determined at the query planning phase. The possibility to pass tuples, transaction snapshots, execution plans or any data between backends is still in the works, yet the possibility to control backends at will is a good step in this direction.

In Postgres 9.4, at least at the moment this post is written, here is how looks the structure visible to users developing a background worker module.

    typedef struct BackgroundWorker
    {
        char bgw_name[BGW_MAXLEN];
        int bgw_flags;
        BgWorkerStartTime bgw_start_time;
        int bgw_restart_time; /* in seconds, or BGW_NEVER_RESTART */
        bgworker_main_type bgw_main;
        char bgw_library_name[BGW_MAXLEN]; /* only if bgw_main is NULL */
        char bgw_function_name[BGW_MAXLEN]; /* only if bgw_main is NULL */
        Datum bgw_main_arg;
    } BackgroundWorker;

Compared to 9.3, there are two new fields called bgw\_library_name and bgw\_function_name that can be defined to load an external function with load\_external\_library when starting dynamically a worker. Note that the priority is given to bgw\_main (defining a function that needs to be already loaded in the server before calling it) even if its related library is not loaded with for example shared\_preload\_libraries. Be aware of that of this could lead easily to server crashes with corrupted memory.

Note that one of the advantages of this implementation is that there is no backward incompatibility with 9.3. So all the bgworkers you have taken time and effort to develop for 9.3 will still be working without any extra modifications in 9.4.

So let's have a look at what this feature can do in more details with the contrib module called worker\_spi, which has been extended to have an example of how this feature works in Postgres core. Here is what happens in the case where the library of worker\_spi has not been loaded at server start.

    postgres=# SHOW shared_preload_libraries;
     shared_preload_libraries
    --------------------------
     
    (1 row)
    postgres=# CREATE EXTENSION worker_spi;
    CREATE EXTENSION
    postgres=# \dx+ worker_spi
    Objects in extension "worker_spi"
              Object Description
    -------------------------------------
     function worker_spi_launch(integer)
    (1 row)

Now worker\_spi can be installed as an extension and adds the function worker\_spi\_launch to launch a worker with a wanted ID. Except launching the worker, this module does nothing else except some dummy database operations on a dedicated schema created at process start.

    postgres=# SELECT worker_spi_launch(1), worker_spi_launch(2);
     worker_spi_launch | worker_spi_launch
    -------------------+-------------------
                     t | t
    (1 row)

And then what happens on server?

    $ ps ux | grep worker
    mpaquier 15594 0.0 1.4 178432 7028 ? Ss 14:57 0:00 postgres: bgworker: worker 1
    mpaquier 15595 0.0 1.4 178376 7132 ? Ss 14:57 0:00 postgres: bgworker: worker 2

Workers are here and running.

Remember that you cannot have more workers than max\_worker\_processes (default at 8) at the same time. This is necessary to allocate at server start a fixed amount of shared memory for worker information. If the registration of the worker fails, worker\_spi\_launch returns false to the client.

    postgres=# select worker_spi_launch(generate_series(3,9));
     worker_spi_launch
    -------------------
     t
     t
     t
     t
     t
     t
     f
    (7 rows)

Using pg\_terminate\_backend, you can as well stop from a client workers that you started previously. There is still no way to directly know the PID of the backend started, but this interface is being worked on and will be available for sure in 9.4. However you can still grab the PID of the new process by having a look at pg\_stat\_activity.

One last thing to remember is that max\_worker\_processes is a limit for the total of both static and dynamic workers, so be sure to have a value of this parameter in line with your needs, especially if your server has many workers loaded automatically when server starts, or you won't be able to start many workers dynamically.
