---
author: Michael Paquier
comments: true
lastmod: 2013-03-21
date: 2013-03-21 03:05:27+00:00
layout: post
type: post
slug: hooks-in-postgres-super-superuser-restrictions
title: 'Hooks in Postgres: super-superuser restrictions'
categories:
- PostgreSQL-2
tags:
- awesome
- background
- database
- executor
- extension
- hook
- module
- open source
- postgres
- postgresql
- process
- tool
- utility
- worker
---

PostgreSQL extensibility is awesome. With things like extensions or custom worker backgrounds, there are many ways for a PostgreSQL developer to create modules without having to touch a single line of the core code at all. Among those tools, PostgreSQL contains a set of hooks that can be used to plug customized code at certain points of the server processing. Hooks are not documented at all, so if you want to know more about them you need either to have a look directly at the PostgreSQL code or to read the slides of [the presentation about hooks given by Guillaume Lelarge at PGcon 2012](http://wiki.postgresql.org/images/e/e3/Hooks_in_postgresql.pdf). 
Personally I recommend the latter, Guillaume's presentation being really good.

You can do many things with hooks, like creating a custom planner, outputting a custom EXPLAIN, running some personalized versions of utilities or control query processing at execution level. Hooks can be loaded as shared libraries using shared\_preload\_libraries or with a simple LOAD command for current session. In this post, I am going to show a restriction on DROP DATABASE using the hook for utility processing. In my case a given database "foodb" can only be dropped by a given user "foo", our godly super-superuser.

When implementing a hook, here is how it should look for the basics.

    #include "postgres.h"
    #include "miscadmin.h"
    #include "tcop/utility.h"
    
    PG_MODULE_MAGIC;
    
    void _PG_init(void);
    void _PG_fini(void);
    
    static char *undroppabledb = "foodb";
    static char *supersuperuser = "foo";
    static ProcessUtility_hook_type prev_utility_hook = NULL;
    
    static void dbrestrict_utility(Node *parsetree,
        const char *queryString,
        ParamListInfo params,
        DestReceiver *dest,
        char *completionTag,
        ProcessUtilityContext context);

\_PG\_init and \_PG\_fini are respectively executed when the library is loaded and unloaded. PG\_MODULE\_MAGIC is necessary to define a PostgreSQL module in the case where it is loaded by server. dbrestrict\_utility will be the function used instead of standard\_ProcessUtility in utility.c.

Here is what you need to do with \_PG\_init and \_PG\_fini to install and uninstall correctly the hook.

    void
    _PG_init(void)
    {
        prev_utility_hook = ProcessUtility_hook;
        ProcessUtility_hook = dbrestrict_utility;
    }
    void
    _PG_fini(void)
    {
        ProcessUtility_hook = prev_utility_hook;
    }

The previous hook pointer is saved in a static variable to avoid any conflicts once the library is unloaded.

Then here is dbrestrict\_utility, which performs the block on DROP DATABASE.

    static
    void dbrestrict_utility(Node *parsetree,
        const char *queryString,
        ParamListInfo params,
        DestReceiver *dest,
        char *completionTag,
        ProcessUtilityContext context)
    {
        /* Do our custom process on drop database */
        switch (nodeTag(parsetree))
        {
            case T_DropdbStmt:
            {
                DropdbStmt *stmt = (DropdbStmt *) parsetree;
                char *username = GetUserNameFromId(GetUserId());
    
                /*
                 * Check that only the authorized superuser foo can
                 * drop the database undroppable_foodb.
                 */
                if (strcmp(stmt->dbname, undroppabledb) == 0 &&
                    strcmp(username, supersuperuser) != 0)
                    ereport(ERROR,
                    (errcode(ERRCODE_INSUFFICIENT_PRIVILEGE),
                        errmsg("Only super-superuser \"%s\" can drop database \"%s\"",
                        supersuperuser, undroppabledb)));
                break;
            }
            default:
                break;
        }
    
        /* Fallback to normal process */
        standard_ProcessUtility(parsetree, queryString, params, dest,
             completionTag, context);
    }

An important thing you should do as much as possible: always provide a safe exit by calling the function hook replaces at the end or the beginning of the new function to avoid weird behaviors. In the case of my example not calling standard\_ProcessUtility would have resulted in blocking all the utilities...  Note that this is of course not mandatory, just be sure about what you do as a hook not correctly coded can break easily a server.

Finally define a Makefile like this one and install the library (the file containing source code is called dbrestrict.c).

    MODULES = dbrestrict
    PG_CONFIG = pg_config
    PGXS := $(shell $(PG_CONFIG) --pgxs)
    include $(PGXS)

OK, now let's test this feature with a couple of superusers.

    postgres=# CREATE ROLE foo SUPERUSER LOGIN;
    CREATE ROLE
    postgres=# CREATE ROLE foo2 SUPERUSER LOGIN;
    CREATE ROLE
    postgres=# \c postgres foo2
    You are now connected to database "postgres" as user "foo2".
    postgres=# CREATE DATABASE foodb; -- before loading restriction
    CREATE DATABASE
    postgres=# DROP DATABASE foodb;
    DROP DATABASE
    postgres=# LOAD 'dbrestrict.so';
    LOAD
    postgres=# CREATE DATABASE foodb; -- after loading restriction
    CREATE DATABASE
    postgres=# LOAD 'dbrestrict.so';
    LOAD
    postgres=# DROP DATABASE foodb;
    ERROR:  Only super-superuser "foo" can drop database "foodb"

Note that superuser "foo2" is not able to drop the database "foodb" once restriction has been loaded.

However user "foo" can drop it freely.

    postgres=# \c postgres foo 
    You are now connected to database "postgres" as user "foo".
    postgres=# LOAD 'dbrestrict.so';
    LOAD
    postgres=# DROP DATABASE foodb;
    DROP DATABASE

As LOAD command is session-based, I had to reload the restriction library each time a reconnection to server was done, but you can make this change permanent by setting shared\_preload\_libraries appropriately in postgresql.conf.

Feel free to play with the code, it is attached to this post as [dbrestrict.tar.gz](http://michael.otacoo.com/wp-content/uploads/2013/03/dbrestrict.tar.gz).
See ya~
