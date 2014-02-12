---
author: Michael Paquier
comments: true
date: 2013-09-13 06:01:01+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-event-triggers
title: 'Postgres 9.3 feature highlight: event triggers'
wordpress_id: 2006
categories:
- PostgreSQL-2
tags:
- 9.3
- alter
- create
- database
- ddl
- drop
- event
- feature
- object
- open source
- postgres
- release
- replication
- table
- trigger
---
Event triggers is a new kind of statement-based trigger added in PostgreSQL 9.3. Compared to normal triggers fired when DML queries run on a given table, event triggers are fired for DDL queries and are global to a database. The use cases of event triggers are various.

  * Restrict the execution of DDL or log/record information related to that
  * Monitor execution of DDL queries for logging or perfomance analysis purposes
  * This has as well some use for replication with for example the generation and extraction of DDL queries executed on server in order to offer the possibility to re-run them in another Postgres node.

Note that in the case of replication, it would be interesting to have a way to generate all the commands run within a given DDL like for example the case of a serial column needing an internal sequence query at table creation. This is not supported in 9.3 though.

For the moment, there are three types of events that can be fired by a DDL trigger:

  * ddl\_command\_start, firing the event trigger before executing a DDL command.
  * ddl\_command\_end, firing the event trigger after executing a DDL command.
  * sql\_drop, event occurring just before ddl\_command\_end for any operation dropping database objects. pg\_event\_trigger\_dropped\_objects can be used with this event to get the list of dropped object when this event occurs.

Also, there are three new SQL commands that can be used to control event triggers in 9.3.

  * [CREATE EVENT TRIGGER](http://www.postgresql.org/docs/9.3/static/sql-createeventtrigger.html), where it is possible to define the name of the event trigger, the event it works with and of course the procedure it fires. Interestingly, it is also possible to apply some filters on the event trigger, by using the command tag of query.
  * [ALTER EVENT TRIGGER](http://www.postgresql.org/docs/9.3/static/sql-altereventtrigger.html), to enable, to disable, to rename the trigger or to change its owner. Like normal triggers, an event trigger execution can be controlled with session\_replication\_role, particularly replica sessions.
  * [DROP EVENT TRIGGER](http://www.postgresql.org/docs/9.3/static/sql-dropeventtrigger.html), as its name lets guess, to simply drop an event trigger.

All the event triggers of server are also listed in a dedicated catalog table called pg\_event\_trigger, whose information can be retrieved using '?dy' in a psql client.

Before moving ahead with some examples, there are two more things to be aware of about event triggers.

  * The list of commands supported for all the events is listed here. Note that for example CREATE/ALTER/DROP EVENT TRIGGER is not listed, so you can interact with event trigger definitions without firing anything.
  * Two variables are created for plpgsql functions: TG\_EVENT for the event name and TG\_TAG for the tag name of command executed.

One of the most simple things you can do with event triggers using a pl/pgsql function is to restrict the usage of some DDL commands or send a notice to the user for a given command. Here is for example how to forbid the execution of CREATE TABLE and CREATE VIEW on server.

    =# CREATE OR REPLACE FUNCTION abort_table_view()
    $# RETURNS event_trigger AS $$
    $# BEGIN
    $# RAISE EXCEPTION 'Execution of command % forbidden', tg_tag;
    $# END;
    $# $$ LANGUAGE plpgsql;
    CREATE FUNCTION
    =# CREATE EVENT TRIGGER abort_table_view ON ddl_command_start
    $# WHEN TAG IN ('CREATE TABLE', 'CREATE VIEW') EXECUTE PROCEDURE abort_table_view();
    CREATE EVENT TRIGGER
    =# CREATE TABLE aa (a int);
    ERROR: P0001: Execution of command CREATE TABLE forbidden
    LOCATION: exec_stmt_raise, pl_exec.c:3041
    =# CREATE VIEW aa AS SELECT * FROM aa;
    ERROR: P0001: Execution of command CREATE VIEW forbidden
    LOCATION: exec_stmt_raise, pl_exec.c:3041

Then, you can improve log information related to DDL queries. Here is another example doing that, saving the start and end times of a command in a table dedicated to that. This idea could be used as a base solution for some performance analysis of DDL queries.

    =# CREATE TABLE log_ddl_info(ddl_tag text, ddl_event text, ddl_time timestamp);
    CREATE TABLE
    =# CREATE OR REPLACE FUNCTION log_ddl_execution()
    $# RETURNS event_trigger AS $$
    $# DECLARE
    $# insertquery TEXT;
    $# BEGIN
    $# insertquery := 'INSERT INTO log_ddl_info VALUES (''' || tg_tag ||''', ''' || tg_event || ''', statement_timestamp())';
    $# EXECUTE insertquery;
    $# RAISE NOTICE 'Recorded execution of command % with event %', tg_tag, tg_event;
    $# END;
    $# $$ LANGUAGE plpgsql;
    CREATE FUNCTION
    =# CREATE EVENT TRIGGER log_ddl_info_start ON ddl_command_start
    $# EXECUTE PROCEDURE log_ddl_execution();
    CREATE EVENT TRIGGER
    =# CREATE EVENT TRIGGER log_ddl_info_end ON ddl_command_end
    $# EXECUTE PROCEDURE log_ddl_execution();
    CREATE EVENT TRIGGER
    =# create table aa (a int);
    NOTICE: 00000: Recorded execution of command CREATE TABLE with event ddl_command_start
    LOCATION: exec_stmt_raise, pl_exec.c:3041
    NOTICE: 00000: Recorded execution of command CREATE TABLE with event ddl_command_end
    LOCATION: exec_stmt_raise, pl_exec.c:3041
    CREATE TABLE
    =# SELECT * FROM log_ddl_info ;
        ddl_tag   |     ddl_event     |          ddl_time
    --------------+-------------------+----------------------------
     CREATE TABLE | ddl_command_start | 2013-09-12 13:28:52.580412
     CREATE TABLE | ddl_command_end   | 2013-09-12 13:28:52.582148
   (2 rows)

Note that implementing this feature with C functions would offer the possibility to log more precise information with session-level data like the user and database involved in the query execution or with the parse tree of query passed to EventTriggerData.

There is also in the documentation a simple example of the usage of sql\_drop and pg\_event\_trigger\_dropped\_objects() you should refer to it to get the basics of how this event works and how things like cascading drop affect it.
