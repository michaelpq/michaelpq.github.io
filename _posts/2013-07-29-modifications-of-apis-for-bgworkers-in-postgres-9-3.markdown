---
author: Michael Paquier
comments: true
lastmod: 2013-07-29
date: 2013-07-29 01:47:51+00:00
layout: post
type: post
slug: modifications-of-apis-for-bgworkers-in-postgres-9-3
title: Modifications of APIs for bgworkers in Postgres 9.3
categories:
- PostgreSQL-2
tags:
- '9.3'
- '9.4'
- API
- architecture
- background
- control
- daemon
- extension
- fdw
- framework
- interface
- maintenance
- modification
- module
- new
- postgres
- postgresql
- postmaster
- process
- server
- structure
- update
- worker
---

Just to make a short recall, [Background worker](http://www.postgresql.org/docs/9.3/static/bgworker.html) is a new plug-in facility similar to hook, extension or FDW, but this time allowing to run customized code in a daemon process managed by the postmaster. This allows, without modifying the core code of the Postgres server, to run automatic maintenance tasks, to collect statistics or to do more fancy stuff like running for example a licence checker for a Postgres server running in a cloud (do what you want with this idea...). However, all the people that have begun development of a background worker module based on PostgreSQL 9.3 beta1 or beta2 need to be aware that there have been modifications in the APIs used by this facility. Those modifications have been made for a couple of reasons.

  1. Postgres 9.4 is introducing new bgworkers functionalities, called dynamic background workers, that needed some adjustments, some of them being related to the fact that bgworker information is stored in shared memory accessible to all the processes of the server in 9.4.
  2. Postgres 9.3 is not out yet as an official release, so changing the APIs now saves years of maintenance pain, and facilitates future developments of background worker modules as they could be easily usable with multiple Postgres server versions

This post is not here to deal with the new bgworker features that are being developed for Postgres 9.4, but just to present the API modifications for 9.3. So let's have a look at the general structure used for the registration of background workers to have a better understanding of what has changed. Here is how it looks like in 9.3 beta2:

    typedef struct BackgroundWorker
    {
        char       *bgw_name;
        int         bgw_flags;
        BgWorkerStartTime bgw_start_time;
        int         bgw_restart_time;       /* in seconds, or BGW_NEVER_RESTART */
        bgworker_main_type bgw_main;
        void       *bgw_main_arg;
        bgworker_sighdlr_type bgw_sighup;
        bgworker_sighdlr_type bgw_sigterm;
    } BackgroundWorker
`
And here is the same structure at the top commit of REL9_3_STABLE as of the date of this post (which will be normally its final shape for release 9.3):

    typedef struct BackgroundWorker
    {
        char        bgw_name[BGW_MAXLEN];
        int         bgw_flags;
        BgWorkerStartTime bgw_start_time;
        int         bgw_restart_time;       /* in seconds, or BGW_NEVER_RESTART */
        bgworker_main_type bgw_main;
        Datum       bgw_main_arg;
    } BackgroundWorker;

The first thing changed is that the background worker name that is not a string anymore. You will need to update your module with for example a snprintf with a fixed length for that. Nothing really complicated.

The second thing to note is that the argument used for bgw\_main\_arg is not anymore a simple pointer but has Datum. In this case also the modification to bring to your own module is not that hard. When passing an argument value, use the Datum-related APIs of postgres.h. Particularly when you need to pass a structure containing multiple argument use that to change a pointer as a Datum, and vice-versa:

    #define DatumGetPointer(X) ((Pointer) (X))
    #define PointerGetDatum(X) ((Datum) (X))

If you do not want to specify any arguments, simply do that at registration:

    worker.bgw_main_arg = (Datum) 0;

This has also as consequence to modify the structure the main function of a bgworker need to have. It is changed from that:

    my_worker_main(void *main_arg)

To that:

    my_worker_main(Datum main_arg)

So be sure to change your functions accordingly to avoid warnings and incompatibilities.

The last thing to note is the removal of bgw\_sighup and bgw\_sigterm that were being used to register some functions to kick when a given signal (SIGHUP or SIGTERM) was received by the background worker. With the old set of APIs, you would have done something like that when registering the worker:

    void
    _PG_init(void)
    {
        BackgroundWorker worker;
        
        worker.bgw_sighup = my_worker_func_for_sighup;
        worker.bgw_sigterm = my_worker_func_for_sigterm;
    
        [... Rest of registration ...]
    }

Now you need to do this operation at the beginning of the main function of the worker before unblocking signals.

    static void
    my_worker_main(Datum main_arg)
    {
        /* Set up the sigterm/sighup signal functions before unblocking them */
        pqsignal(SIGTERM, my_worker_func_for_sigterm);
        pqsignal(SIGHUP, my_worker_func_for_sighup);
    
        /* We're now ready to receive signals */
        BackgroundWorkerUnblockSignals();
    
        [... Continue process ...]
    }

Globally, those modifications do not require much modifications (maximum of 10 lines) so you will be able to catch up easily, don't worry. You can refer to my set of [background worker examples in github](https://github.com/michaelpq/pg_plugins) that has been updated to reflect the API changes. There is also the contrib module called worker\_spi which has been updated to reflect the API modifications.
