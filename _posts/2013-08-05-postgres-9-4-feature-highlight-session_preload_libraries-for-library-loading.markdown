---
author: Michael Paquier
lastmod: 2013-08-05
date: 2013-08-05 06:24:32+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-session_preload_libraries-for-library-loading
title: 'Postgres 9.4 feature highlight: session_preload_libraries for library loading'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- session
- preload
- library
- load
- 9.4
- highlight
- feature
- session_preload_libraries

---

PostgreSQL already offers a couple of ways to load custom library into
a server instance:

  * LOAD, the most straight-forward way allowing to load a library in a
  given session. This is particularly useful for hooks. Non-superusers
  can only upload libraries from the plugin directory of the installation.
  * local_preload_libraries, to load libraries at connection time. As this
  option can be set by any users, only libraries that are located in the
  plugin directory of the installation can be loaded. This parameter value
  cannot be changed after connection start.
  * shared_preload_libraries, to load libraries at server start. This is
  necessary in the case of shared memory allocation at server level or
  starting background workers. Note that if this parameter is modified,
  the server needs to be restarted.

PostgreSQL 9.4 introduces a new level of library preloading with the
introduction of the GUC parameter called session\_preload\_libraries.
This preloading is session-based and orientated to temporary tasks like
for example analysis of queries having an incorrect plan with auto\_explain
(as mentioned by the [documentation]
(http://www.postgresql.org/docs/devel/static/runtime-config-client.html#RUNTIME-CONFIG-CLIENT-PRELOAD)
directly), or measurement analysis by using a library with some hooks.
Like local\_preload\_libraries, libraries are loaded at connection start,
but it is possible to control what are the user sessions where libraries
are loaded without specifying a LOAD command. In order to do that, you
can change this parameter value for a user with ALTER ROLE. Note that
only superusers can change session\_preload\_libraries, and that it does
not require a server restart. Also changing its value has no effect on
existing sessions, only on the new ones.

So let's have a look more in details at what it can do. For this test,
I used a simple library called errhook changing the error code for a
duplicated table to an error meaning that this feature is not supported.
This has no real logical meaning in a server... except that it is just
simple. Here is the code for that:

    #include "postgres.h"
    #include "miscadmin.h"
    #include "utils/elog.h"
    #include "fmgr.h"
    
    PG_MODULE_MAGIC;

    void _PG_init(void);
    void _PG_fini(void);
    static emit_log_hook_type prev_log_hook = NULL;
    static void errhook_change(ErrorData *data);
    
    static void errhook_change(ErrorData *data)
    {
        /* Change error code */
        if (data->sqlerrcode == ERRCODE_DUPLICATE_TABLE)
        data->sqlerrcode = ERRCODE_FEATURE_NOT_SUPPORTED;
    }
        
    /*
     * _PG_init
     * Install the hook.
     */
    void _PG_init(void)
    {
        prev_log_hook = emit_log_hook;
        emit_log_hook = errhook_change;
    }

    /*
     * _PG_fini
     * Uninstall the hook.
     */
    void _PG_fini(void)
    {
        emit_log_hook = prev_log_hook;
    }

With the following Makefile:

    MODULES = errhook
    PG_CONFIG = pg_config
    PGXS := $(shell $(PG_CONFIG) --pgxs)
    include $(PGXS)

Now, let's create a new role called 'foo' on the server and change its
value of session\_preload\_libraries.

    =# CREATE ROLE foo SUPERUSER LOGIN;
    CREATE ROLE
    =# ALTER ROLE foo SET session_preload_libraries = 'errhook';
    ALTER ROLE
    =# \drds foo
     List of settings Role | Database |              Settings
     ----------------------+----------+-----------------------------------
                      foo  |          | session_preload_libraries=errhook
    (1 row)
    =# \drds postgres
    No matching settings found.

The default user postgres has nothing uploaded, so in his case the error
code returned in the case of a duplicated table is...

    =# SELECT current_role;
     current_user
    --------------
        postgres
    (1 row)
    =# CREATE TABLE aa ();
    CREATE TABLE
    =# CREATE TABLE aa ();
    ERROR: 42P07: relation "aa" already exists
    LOCATION: heap_create_with_catalog, heap.c:1046

And now for user foo:

    =# select current_user;
     current_user
    --------------
            foo
    (1 row)
    =# CREATE TABLE aa ();
    ERROR: 0A000: relation "aa" already exists
    LOCATION: heap_create_with_catalog, heap.c:1046

And the error code is correctly changed, the library errhook has been
preloaded for the specified user. You can reset its value once your tasks
are done with ALTER ROLE RESET:

    =# ALTER ROLE foo RESET session_preload_libraries;
    ALTER ROLE
