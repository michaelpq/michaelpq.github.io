---
author: Michael Paquier
lastmod: 2015-03-27
date: 2015-03-27 13:53:45+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-foreign-table-inheritance
title: 'Postgres 9.5 feature highlight - Scale-out with Foreign Tables now part of Inheritance Trees'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- highlight
- 9.5
- foreign
- table
- inheritance
- tree
- fdw
- postgres_fdw
- wrapper
- parent
- child
- scan

---

This week the following commit has landed in PostgreSQL code tree, introducing
a new feature that will be released in 9.5:

    commit: cb1ca4d800621dcae67ca6c799006de99fa4f0a5
    author: Tom Lane <tgl@sss.pgh.pa.us>
    date: Sun, 22 Mar 2015 13:53:11 -0400
    Allow foreign tables to participate in inheritance.

    Foreign tables can now be inheritance children, or parents.  Much of the
    system was already ready for this, but we had to fix a few things of
    course, mostly in the area of planner and executor handling of row locks.

    [...]

    Shigeru Hanada and Etsuro Fujita, reviewed by Ashutosh Bapat and Kyotaro
    Horiguchi, some additional hacking by me

As mentioned in the commit message, [foreign tables]
(http://www.postgresql.org/docs/devel/static/sql-createforeigntable.html)
can now be part of an inheritance tree, be it as a parent or as a child.

Well, seeing this commit, one word comes immediately in mind: in-core sharding.
And this feature opens such possibilities with for example a parent table managing
locally a partition of foreign child tables located on a set of foreign servers.

PostgreSQL offers some way to already do [partitioning]
(http://www.postgresql.org/docs/devel/static/ddl-partitioning.html) by using
CHECK constraints (non-intuitive system but there may be improvements in a
[close future](http://www.postgresql.org/message-id/54EC32B6.9070605@lab.ntt.co.jp)
in this area). Now combined with the feature committed, here is a small
example of how to do sharding without the need of any external plugin or
tools, only [postgres_fdw](http://www.postgresql.org/docs/devel/static/postgres-fdw.html)
being needed to define foreign tables.

Now let's take the example of 3 Postgres servers, running on the same machine
for simplicity, using ports 5432, 5433 and 5434. 5432 will hold a parent table,
that has two child tables, the two being foreign tables, located on servers
listening at 5433 and 5434. The test case is simple: a log table partitioned
by year.

First on the foreign servers, let's create the child tables. Here it is
for the table on server 5433:

    =# CREATE TABLE log_entry_y2014(log_time timestamp,
           entry text,
           check (date(log_time) >= '2014-01-01' AND
                  date(log_time) < '2015-01-01'));
    CREATE TABLE

And the second one on 5434:

    =# CREATE TABLE log_entry_y2015(log_time timestamp,
           entry text,
           check (date(log_time) >= '2015-01-01' AND
                  date(log_time) < '2016-01-01'));
    CREATE TABLE

Now it is time to do the rest of the work on server 5432, by creating a
parent table, and foreign tables that act as children, themselves linking
to the relations on servers 5433 and 5434 already created. First here is
some preparatory work to define the foreign servers.

    =# CREATE EXTENSION postgres_fdw;
    CREATE EXTENSION
    =# CREATE SERVER server_5433 FOREIGN DATA WRAPPER postgres_fdw
       OPTIONS (host 'localhost', port '5433', dbname 'postgres');
    CREATE SERVER
    =# CREATE SERVER server_5434 FOREIGN DATA WRAPPER postgres_fdw
       OPTIONS (host 'localhost', port '5434', dbname 'postgres');
    CREATE SERVER
    =# CREATE USER MAPPING FOR PUBLIC SERVER server_5433 OPTIONS (password '');
    CREATE USER MAPPING
    =# CREATE USER MAPPING FOR PUBLIC SERVER server_5434 OPTIONS (password '');
    CREATE USER MAPPING

And now here are the local tables (note that it is possible as well to create
CHECK constraints on the foreign child tables to give the planner hints on how
queriea would behave remotely as no constraint check is done locally on foreign
tables):

    =# CREATE TABLE log_entries(log_time timestamp, entry text);
    CREATE TABLE
    =# CREATE FOREIGN TABLE log_entry_y2014_f (log_time timestamp,
                                               entry text)
       INHERITS (log_entries) SERVER server_5433 OPTIONS (table_name 'log_entry_y2014');
    CREATE FOREIGN TABLE
    =# CREATE FOREIGN TABLE log_entry_y2015_f (log_time timestamp,
                                               entry text)
       INHERITS (log_entries) SERVER server_5434 OPTIONS (table_name 'log_entry_y2015');
    CREATE FOREIGN TABLE

The tuple insertion from the parent table to the children can be achieved
using for example a plpgsql function like this one with a trigger on
the parent relation log\_entries.

    =# CREATE FUNCTION log_entry_insert_trigger()
       RETURNS TRIGGER AS $$
       BEGIN
         IF date(NEW.log_time) >= '2014-01-01' AND date(NEW.log_time) < '2015-01-01' THEN
           INSERT INTO log_entry_y2014_f VALUES (NEW.*);
         ELSIF date(NEW.log_time) >= '2015-01-01' AND date(NEW.log_time) < '2016-01-01' THEN
           INSERT INTO log_entry_y2015_f VALUES (NEW.*);
         ELSE
           RAISE EXCEPTION 'Timestamp out-of-range';
         END IF;
         RETURN NULL;
       END;
       $$ LANGUAGE plpgsql;
     CREATE FUNCTION
     =# CREATE TRIGGER log_entry_insert BEFORE INSERT ON log_entries
        FOR EACH ROW EXECUTE PROCEDURE log_entry_insert_trigger();
     CREATE TRIGGER

Once the environment is set and in place, log entries can be insertedon the
parent tables, and will be automatically sharded across the foreign servers.

    =# INSERT INTO log_entries VALUES (now(), 'Log entry of 2015');
    INSERT 0 0
    =# INSERT INTO log_entries VALUES (now() - interval '1 year', 'Log entry of 2014');
    INSERT 0 0
    =# INSERT INTO log_entries VALUES (now(), 'Log entry of 2015-2');
    INSERT 0 0
    =# INSERT INTO log_entries VALUES (now() - interval '1 year', 'Log entry of 2014-2');
    INSERT 0 0

The entries inserted are of course localized on their dedicated foreign tables:

    =# SELECT * FROM log_entry_y2014_f;
              log_time          |        entry
    ----------------------------+---------------------
     2014-03-27 22:34:04.952531 | Log entry of 2014
     2014-03-27 22:34:28.06422  | Log entry of 2014-2
    (2 rows)
    =# SELECT * FROM log_entry_y2015_f;
              log_time          |        entry
    ----------------------------+---------------------
     2015-03-27 22:31:19.042066 | Log entry of 2015
     2015-03-27 22:34:18.425944 | Log entry of 2015-2
    (2 rows)

Something useful to note as well is that EXPLAIN is now verbose enough to
identify all the tables targetted by a DML. For example in this case (not
limited to foreign tables):

    =# EXPLAIN UPDATE log_entries SET log_time = log_time + interval '1 day';
                                          QUERY PLAN
    -----------------------------------------------------------------------------------
     Update on log_entries  (cost=0.00..296.05 rows=2341 width=46)
       Update on log_entries
       Foreign Update on log_entry_y2014_f
       Foreign Update on log_entry_y2015_f
       ->  Seq Scan on log_entries  (cost=0.00..0.00 rows=1 width=46)
       ->  Foreign Scan on log_entry_y2014_f  (cost=100.00..148.03 rows=1170 width=46)
       ->  Foreign Scan on log_entry_y2015_f  (cost=100.00..148.03 rows=1170 width=46)
    (7 rows)

And this makes a day.
