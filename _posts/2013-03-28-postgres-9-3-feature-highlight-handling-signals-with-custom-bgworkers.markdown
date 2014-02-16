---
author: Michael Paquier
comments: true
lastmod: 2013-03-28
date: 2013-03-28 03:13:01+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-handling-signals-with-custom-bgworkers
title: 'Postgres 9.3 feature highlight: handling signals with custom bgworkers'
wordpress_id: 1787
categories:
- PostgreSQL-2
tags:
- '9.3'
- background
- bgworker
- control
- custom
- database
- example
- github
- handling
- latch
- latency
- log
- open source
- pg_workers
- postgres
- postgresql
- postmaster
- project
- shared memory
- sighup
- signal
- sigterm
- worker
---

Similarly to a normal PostgreSQL child process, a custom background worker should be running using a loop that can be interrupted with signals to update a given status or simply exit the process. Two types of signals are handled by custom background workers in the PostgreSQL architecture: SIGHUP and SIGTERM.

When such signals are received by a bgworker, you should be aware that processing similar to what is done for a normal backend process might be needed. For example, if your custom bgworker uses some GUC parameters, the process needs to take proper action to reload configuration parameters. Even if there are already good examples in the PostgreSQL source code for bgworkers, I noticed that there are no examples focusing only on certain fundamentals of bgworker. As someone who likes simple things, I think that this is essential to get the essence of what this feature can do piece by piece. 

So here is in this post an example of bgworker that I wrote for beginners in order to understand only the fundamentals of signal handling. First you need to know that it is necessary to store a static variable to store the status of representing if signal has been activated or not in a way similar to that:

    static bool got_sigterm = false;
    static bool got_sighup = false;

You also need dedicated functions to set those flags to true if a signal is received by the worker.

    static void
    hello_sigterm(SIGNAL_ARGS)
    {
        got_sigterm = true;
    }
    
    static void
    hello_sighup(SIGNAL_ARGS)
    {
        got_sighup = true;
    }

A dedicated function that is used as a main loop for processing is essential as well.

    static void
    hello_main(void *main_arg)
    {
        /* We're now ready to receive signals */
        BackgroundWorkerUnblockSignals();
        while (true)
        {
            /* Process signals */
            if (got_sighup)
            {
                got_sighup = false;
                ereport(LOG, (errmsg("hello signal: processed SIGHUP")));
            }
    
            if (got_sigterm)
            {
                /* Simply exit */
                ereport(LOG, (errmsg("hello signal: processed SIGTERM")));
                proc_exit(0);
            }
        }
        proc_exit(0)
    }

Note the call to BackgroundWorkerUnblockSignals. This is extremely important in order to allow the reception of signals by the background worker.

Once you have this basic infrastructure in place, you need to register this worker process correctly with something like that:

    void
    _PG_init(void)
    {
        BackgroundWorker worker;
        worker.bgw_flags = 0;
        worker.bgw_start_time = BgWorkerStart_PostmasterStart;
        worker.bgw_main = hello_main;
        worker.bgw_sigterm = hello_sigterm;
        worker.bgw_sighup = hello_sighup;
        worker.bgw_name = "hello_signal";
        /* Wait 10 seconds for restart before crash */
        worker.bgw_restart_time = 10;
        worker.bgw_main_arg = NULL;
        RegisterBackgroundWorker(&worker;);
    }

Also don't forget that you need a header similar to that to have this code working properly.

    /* Some general headers for custom bgworker facility */
    #include "postgres.h"
    #include "fmgr.h"
    #include "postmaster/bgworker.h"
    #include "storage/ipc.h"
    
    /* Allow load of this module in shared libs */
    PG_MODULE_MAGIC;
    
    /* Entry point of library loading */
    void _PG_init(void);

Also, be sure that when you create a custom background worker, signal handling is similar to what is done for normal backend process. For example, the configuration file reload should be processed if SIGHUP is received. You can do that properly by calling ProcessConfigFile in a manner similar to that in the main loop.

    if (got_sighup)
    {
        /* Process config file */
        ProcessConfigFile(PGC_SIGHUP);
        got_sighup = false;
        ereport(LOG, (errmsg("hello signal: processed SIGHUP")));
    }

In order to bring more fluidity to you custom worker and not have it use all the CPU of your server by running continuously, don't forget to define a latch to control some sleep period of your worker. It can be defined with that:

    /* The latch used for this worker to manage sleep correctly */
    static Latch signalLatch;

Then when entering in the main loop process, initialize the latch with that:

    InitializeLatchSupport();
    InitLatch(&signalLatch;);

Finally you need to set up your main loop to use the latch

    while (true)
    {
        int rc;
    
        /* Wait 1s */
        rc = WaitLatch(&signalLatch;,
                WL_LATCH_SET | WL_TIMEOUT | WL_POSTMASTER_DEATH,
                1000L);
        ResetLatch(&signalLatch;);
        
        /* Emergency bailout if postmaster has died */
        if (rc & WL_POSTMASTER_DEATH)
            proc_exit(1);
        
        [... code for signal handling ...]
    }

You can also set up the latch such as the sleep will stop immediately if a signal is received. Simply add the following call in hello\_sighup and hello\_sigterm to do that.

    SetLatch(&signalLatch;);

This code can be found on Github as repository [pg\_workers](https://github.com/michaelpq/pg_workers). I created it to group all the bgworker examples I wrote using the facility of PostgreSQL 9.3 and above. You can find the example presented in this post in the folder hello\_signal.
