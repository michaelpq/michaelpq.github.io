---
author: Michael Paquier
comments: true
lastmod: 2013-06-26
date: 2013-06-26 00:33:20+00:00
layout: post
type: post
slug: postgres-devel-some-psql-tricks
title: 'Postgres devel: some psql tricks'
wordpress_id: 1993
categories:
- PostgreSQL-2
tags:
- addition
- application
- catalog
- client
- development
- feature
- postgres
- postgresql
- psql
- psqlrc
- query
- setting
- trick
---

psql, the command client delivered with postgres core, has many options and is in this way highly customizable. For example, you can use a ~/.psqlrc file to upload automatically some customized settings when launching psql. Here are some general tips to be aware off as a common user.

When launching psql, you might want to display a welcome message or an help menu. This can be done with the command \echo. For example, such a command:

    \echo '\nWelcome, nice guy\n'

Will be displayed like that when using psql.

    $ psql
    
    Welcome, nice guy
    
    psql (9.4devel)
    Type "help" for help

Of course such level of customization depends on your narcissicism, so this could be more useful when displaying an help menu at the attention of user, like this one:

    \echo 'Fantastic option menu:'
    \echo '\t:cooloption1\t-- My wonderful query 1'
    \echo '\t:cooloption2\t-- My wonderful query 2'
    \echo '\t:cooloption3\t-- My wonderful query 3'
    \echo ''

And it displays like that:

    $ psql
    Fantastic option menu:
        :cooloption1        -- My wonderful query 1
        :cooloption2        -- My wonderful query 2
        :cooloption3        -- My wonderful query 3
    
    psql (9.4devel)
    Type "help" for help.

Once you know how to make the user aware of customized options, use the command \set to actually define them. Here is for example a command to display for how long current session is running (more simple with pg\_postmaster\_start\_time btw).

    \set uptime 'select now() - backend_start as uptime from pg_stat_activity where pid = pg_backend_pid();'

Or here is an option to get easily slave node activity.

    \set slaves 'select application_name, pg_xlog_location_diff(sent_location, flush_location) as replay_delta, sync_priority, sync_state from pg_stat_replication;'

Something I also personally like is a simple command to clear the screen.

    \set clear '\\! clear;'

Then call those options with simply :$OPTION. Note that those are TAB-sensitive.

Another thing that might be useful customizing is the prompt. The default is set as '%/=%# ', displaying the name of the database. Also if depending on the connected user, '#' is displayed for a superuser, or '>' for someone else. However you can be more complete by setting it to something like that:

    \set PROMPT1 'user=%n,db=%/@%m:%>=%# '

This prompts the user name (%n), the database name (%/), the host name (%m, [local] if using a local Unix socket) and the port number (%>), displaying something like that:

    user=foo,db=toto@[local]:5432=#

Note that you can also play with the colors. Why not printing each field with a different color?

When using psql for development purposes, you might want to have more information about an error than a normal user because you work on a specific feature or application. Simply use verbosity to get more output. This option got even better in 9.3 with the addition of new fields for database, schema, columns, tables and constraints.

    \set VERBOSITY verbose

In order to display how long a query takes, you can use timing.

    \timing

Sometimes depending on how large a table displays on the rendering screen, using an expanded display might be useful, or \x or \pset expanded to facilitate your life for that.

    \x auto

Also, in case you want to fallback to the default settings and ignore all the things inside psql, simply use -X when invocating psql.
