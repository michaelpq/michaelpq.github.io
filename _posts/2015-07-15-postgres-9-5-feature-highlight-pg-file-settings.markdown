---
author: Michael Paquier
lastmod: 2015-07-15
date: 2015-07-15 07:47:33+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-pg-file-settings
title: 'Postgres 9.5 feature highlight - pg_file_settings to finely track system configuration'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.5
- view
- function
- monitoring

---

PostgreSQL 9.5 is coming up with a new feature aimed at simplifying
tracking of GUC parameters when those are set in a multiple set of
files by introducing a new system view called pg\_file\_settings:

    commit: a97e0c3354ace5d74c6873cd5e98444757590be8
    author: Stephen Frost <sfrost@snowman.net>
    date: Fri, 8 May 2015 19:09:26 -0400
    Add pg_file_settings view and function

    The function and view added here provide a way to look at all settings
    in postgresql.conf, any #include'd files, and postgresql.auto.conf
    (which is what backs the ALTER SYSTEM command).

    The information returned includes the configuration file name, line
    number in that file, sequence number indicating when the parameter is
    loaded (useful to see if it is later masked by another definition of the
    same parameter), parameter name, and what it is set to at that point.
    This information is updated on reload of the server.

    This is unfiltered, privileged, information and therefore access is
    restricted to superusers through the GRANT system.

    Author: Sawada Masahiko, various improvements by me.
    Reviewers: David Steele

In short, [pg\_file\_settings]
(https://www.postgresql.org/docs/devel/static/view-pg-file-settings.html)
can prove to be quite useful when using a set of configuration files to
set the server when including them using for example include or
include\_if\_not\_exists. Hence, for example let's imagine a server with
the following, tiny configuration:

    $ cat $PGDATA/postgresql.conf
    shared_buffers = '1GB'
    work_mem = '50MB'
    include = 'other_params.conf'
    $ cat $PGDATA/other_params.conf
    log_directory = 'pg_log'
    logging_collector = on
    log_statement = 'all'

Then this new system view is able to show up from where each parameter
comes from and the value assigned to it:

    =# SELECT * FROM pg_file_settings;
              sourcefile          | sourceline | seqno |       name        | setting | applied | error
    ------------------------------+------------+-------+-------------------+---------+---------+-------
     /to/pgdata/postgresql.conf   |          1 |     1 | shared_buffers    | 1GB     | t       | null
     /to/pgdata/postgresql.conf   |          2 |     2 | work_mem          | 50MB    | t       | null
     /to/pgdata/other_params.conf |          1 |     3 | log_directory     | pg_log  | t       | null
     /to/pgdata/other_params.conf |          2 |     4 | logging_collector | on      | t       | null
     /to/pgdata/other_params.conf |          3 |     5 | log_statement     | all     | t       | null
     (5 rows)

Among the information given, such as the line of the configuration file
where the parameter has been detected, is what makes this view useful for
operators: "applied" is a boolean to define if a given parameter *can* be
applied on server or not. If the parameter cannot be applied correctly,
it is possible to see the reason why it could not have been applied by
looking at the field "error".

Note that the configuration file postgresql.auto.conf is also taken into
account. Then let's see what happens when setting new values for parameters
already defined in other files:

    =# ALTER SYSTEM SET work_mem = '25MB';
    ALTER SYSTEM
    =# ALTER SYSTEM SET shared_buffers = '250MB';
    ALTER SYSTEM
    =# SELECT sourcefile, name, setting, applied, error
       FROM pg_file_settings WHERE name IN ('work_mem', 'shared_buffers');
               sourcefile            |      name      | setting | applied |            error
    ---------------------------------+----------------+---------+---------+------------------------------
     /to/pgdata/postgresql.conf      | shared_buffers | 1GB     | f       | null
     /to/pgdata/postgresql.conf      | work_mem       | 50MB    | f       | null
     /to/pgdata/postgresql.auto.conf | work_mem       | 25MB    | t       | null
     /to/pgdata/postgresql.auto.conf | shared_buffers | 250MB   | f       | setting could not be applied
    (4 rows)

Note that as already mentioned above, "applied" defines if the parameter
can be applied or not on the server, but that is actually the state that
a server would face after reloading parameters on it. Hence in this case
if parameters are reloaded, the new value of work\_mem which is 25MB can
be applied successfully, while the new value of shared\_buffers, which is
going to need a server restart to be applied, has been selected as the
correct candidate, but its new value cannot be applied for the reason
given out by the view. Then when restarting the server, values are
applied again for all fields:

    =# SELECT sourcefile, name, setting, applied, error
       FROM pg_file_settings WHERE name IN ('work_mem', 'shared_buffers');
                sourcefile           |      name      | setting | applied | error
    ---------------------------------+----------------+---------+---------+-------
     /to/pgdata/postgresql.conf      | shared_buffers | 1GB     | f       | null
     /to/pgdata/postgresql.conf      | work_mem       | 50MB    | f       | null
     /to/pgdata/postgresql.auto.conf | work_mem       | 25MB    | t       | null
     /to/pgdata/postgresql.auto.conf | shared_buffers | 250MB   | t       | null
    (4 rows)

And it is possible to clearly see the values that are selected by the system
for each parameter.

Incorrect parameters also have a special treatment, for example by defining
a parameter that server cannot identify properly here is what
pg\_file\_settings complains about:

    =# SELECT sourcefile, name, error FROM pg_file_settings WHERE name = 'incorrect_param';
              sourcefile          |      name       |                error
    ------------------------------+-----------------+--------------------------------------
     /to/pgdata/other_params.conf | incorrect_param | unrecognized configuration parameter
    (1 row)

This is definitely going to be useful for operators who daily manipulate
large sets of configuration files to determine if a parameter modified
will be able to be taken into account by the server correctly or not.
And that's a very appealing for the upcoming 9.5.
