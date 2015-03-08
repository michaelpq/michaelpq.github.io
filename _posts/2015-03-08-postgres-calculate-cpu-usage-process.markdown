---
author: Michael Paquier
lastmod: 2015-03-05
date: 2015-03-05 10:32:33+00:00
layout: post
type: post
slug: postgres-calculate-cpu-usage-process
title: 'Hack to calculate CPU usage of a Postgres backend process'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- process
- usage
- rusage
- cpu
- processor
- process
- user
- system

---

When working on testing WAL compression, I developed a simple hack able to
calculate the amount of CPU used by a single Postgres backend process during
its lifetime using [getrusage](http://linux.die.net/man/2/getrusage) invoked
at process startup and shutdown. This thing is not aimed for an integration
into core, still it may be useful for people who need to measure the amount
of CPU used for a given set of SQL queries when working on a patch. Here is
the patch, with no more than 20 lines:

    diff --git a/src/backend/tcop/postgres.c b/src/backend/tcop/postgres.c
    index 33720e8..d96a6c6 100644
    --- a/src/backend/tcop/postgres.c
    +++ b/src/backend/tcop/postgres.c
    @@ -32,6 +32,8 @@
     #include <sys/resource.h>
     #endif
     
    +#include <sys/resource.h>
    +
     #ifndef HAVE_GETRUSAGE
     #include "rusagestub.h"
     #endif
    @@ -174,6 +176,10 @@ static bool RecoveryConflictPending = false;
     static bool RecoveryConflictRetryable = true;
     static ProcSignalReason RecoveryConflictReason;
 
    +/* Amount of user and system time used, tracked at start */
    +static struct timeval user_time;
    +static struct timeval system_time;
    +
     /* ----------------------------------------------------------------
      *		decls for routines only used in this file
      * ----------------------------------------------------------------
    @@ -3555,6 +3561,12 @@ PostgresMain(int argc, char *argv[],
     	StringInfoData input_message;
     	sigjmp_buf	local_sigjmp_buf;
     	volatile bool send_ready_for_query = true;
    +	struct rusage r;
    +
    +	/* Get start usage for reference point */
    +	getrusage(RUSAGE_SELF, &r);
    +	memcpy((char *) &user_time, (char *) &r.ru_utime, sizeof(user_time));
    +	memcpy((char *) &system_time, (char *) &r.ru_stime, sizeof(system_time));
 
     	/* Initialize startup process environment if necessary. */
     	if (!IsUnderPostmaster)
    @@ -4228,6 +4240,14 @@ PostgresMain(int argc, char *argv[],
     			case 'X':
     			case EOF:
 
    +				/* Get stop status of process and log comparison with start */
    +				getrusage(RUSAGE_SELF, &r);
    +				elog(LOG,"user diff: %ld.%06ld, system diff: %ld.%06ld",
    +					 (long) (r.ru_utime.tv_sec - user_time.tv_sec),
    +					 (long) (r.ru_utime.tv_usec - user_time.tv_usec),
    +					 (long) (r.ru_stime.tv_sec - system_time.tv_sec),
    +					 (long) (r.ru_stime.tv_usec - system_time.tv_usec));
    +
     				/*
     				 * Reset whereToSendOutput to prevent ereport from attempting
     				 * to send any more messages to client.

Once backend code is compiled with it, logs will be filled with entries
showing the amount of user and system CPU consumed during the process
lifetime. Do not forget to use log\_line\_prefix with %p to associate
what is the PID of process whose resource is calculated. For example,
let's take the following test case:

    =# show log_line_prefix;
     log_line_prefix
    -----------------
     PID %p:
    (1 row)
    =# select pg_backend_pid();
     pg_backend_pid
    ----------------
               7502
    (1 row)
    =# CREATE TABLE huge_table AS SELECT generate_series(1,1000000);
    SELECT 1000000

It results in a log entry with the result wanted once connection is ended:

    PID 7502: LOG:  user diff: 1.329707, system diff: 0.107755

Developers, feel free to use it for your own stuff.
