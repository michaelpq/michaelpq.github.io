---
author: Michael Paquier
comments: true
date: 2013-02-12 08:12:07+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-hello-world-with-custom-bgworkers
title: 'Postgres 9.3 feature highlight: "Hello World" with custom bgworkers'
wordpress_id: 1647
categories:
- PostgreSQL-2
tags:
- '9.3'
- background
- bgworker
- control
- custom
- database
- free
- hello world
- latch
- latency
- log
- open source
- postgres
- postgresql
- postmaster
- shared memory
- worker
---

Based on my [previous experience using custom background workers](http://michael.otacoo.com/postgresql-2/postgres-9-3-feature-highlight-custom-background-workers/) (new feature of PostgreSQL 9.3), here is more detailed example of bgworker doing a simple "Hello World" in the server logs.

Well, the example provided in this post does a little bit more than logging a simple "Hello World", as logging is controlled by a loop running at a given interval of time. Also, the process can be immediately stopped even during its sleep with SIGTERM. So here is in more details how this is done.

#### Header files

    /* Minimum set of headers */
    #include "postgres.h"
    #include "postmaster/bgworker.h"
    #include "storage/ipc.h"
    #include "storage/latch.h"
    #include "storage/proc.h"
    #include "fmgr.h"

This is the minimal set of header files that needs to be provided in order to have the bgworker working correctly. Note that in the case of this example, the sleep time is controlled by a Latch on the process of the background worker, explaining why latch.h and proc.h are included.

#### Declarations

    /* Essential for shared libs! */
    PG_MODULE_MAGIC;
    
    /* Entry point of library loading */
    void _PG_init(void);
    
    /* Signal handling */
    static bool got_sigterm = false;

PG\_MODULE\_MAGIC is absolutely necessary for libraries loaded via shared\_preload\_libraries or server will fail with a FATAL error. Then the only function needed in library is \_PG\_init, entry point to register the bgworker using the dedicated APIs. Finally a static boolean is used as a flag for SIGTERM activation.  

#### Initialization

    void
    _PG_init(void)
    {
        BackgroundWorker    worker;
    
        /* Register the worker processes */
        worker.bgw_flags = BGWORKER_SHMEM_ACCESS;
        worker.bgw_start_time = BgWorkerStart_RecoveryFinished;
        worker.bgw_main = hello_main;
        worker.bgw_sighup = NULL;
        worker.bgw_sigterm = hello_sigterm;
        worker.bgw_name = "hello world";
        worker.bgw_restart_time = BGW_NEVER_RESTART;
        worker.bgw_main_arg = NULL;
        RegisterBackgroundWorker(&worker;);
    }

This portion of code is used to register the new worker. In this example bgw\_start\_time is set to start only once the system has reached a stable read-write state. The process is also allowed access to shared memory with the flag BGWORKER\_SHMEM\_ACCESS (this is used for MyProc, as this is statically included in procarray.c). Finally there are definitiosn for the functions used first as a main loop for logging of "Hello World" and for the function to kick when there is a SIGTERM on background worker. The process is requested not to restart in case of a crash.  

#### Main loop

    static void
    hello_main(void *main_arg)
    {
        /* We're now ready to receive signals */
        BackgroundWorkerUnblockSignals();
        while (!got_sigterm)
        {
            int     rc;
            /* Wait 10s */
            rc = WaitLatch(&MyProc-;>procLatch,
                    WL_LATCH_SET | WL_TIMEOUT | WL_POSTMASTER_DEATH,
                    10000L);
            ResetLatch(&MyProc-;>procLatch);	
            elog(LOG, "Hello World!"); 	/* Say Hello to the world */
        }
        proc_exit(0);
    }

This is the main loop used for the background process. As long as SIGTERM is not received, the process will continue to loop and log "Hello World" every 10s, time interval being symbolized by 10000L. Note that WaitLatch can be awaken with different events: timeout of the time interval provided, Latch being set or postmaster death.

#### SIGTERM handler

    static void
    hello_sigterm(SIGNAL_ARGS)
    {
        int         save_errno = errno;
        got_sigterm = true;
        if (MyProc)
            SetLatch(&MyProc-;>procLatch);
        errno = save_errno;
    }

When SIGTERM is used on the process, the sleep time previously invoked with WaitLatch is stopped with SetLatch immediately. This is controlled by flag WL\_LATCH\_SET that awakes the Latch when set properly.

#### Makefile

    MODULES = hello_world
    PG_CONFIG = pg_config
    PGXS := $(shell $(PG_CONFIG) --pgxs)
    include $(PGXS)

This is a simple Makefile. Be sure to name the file containing the code given in this post as hello\_world.c. The library generated will be called hello\_world.so.

Once this code is run, you will be able to see the process running with a simple ps command.

    $ ps x | grep "hello"
    13327   ??  Ss     0:00.00 postgres: bgworker: hello world 

Be sure to set this variable in postgresql.conf to load the worker correctly.

    shared_preload_libraries = 'hello_world'
