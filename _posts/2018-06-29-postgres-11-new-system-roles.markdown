---
author: Michael Paquier
lastmod: 2018-06-29
date: 2018-06-29 04:50:45+00:00
layout: post
type: post
slug: postgres-11-new-system-roles
title: 'Postgres 11 highlight - New System Roles'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 11
- system
- superuser
- administration

---

A new set of system roles leveraging the past existence of superuser-only
access for some features has been added to leverage security on an instance
of PostgreSQL.  The following commit has added them, and is part of 11:

    commit: 0fdc8495bff02684142a44ab3bc5b18a8ca1863a
    author: Stephen Frost <sfrost@snowman.net>
    date: Fri, 6 Apr 2018 14:47:10 -0400
    Add default roles for file/program access

    This patch adds new default roles named 'pg_read_server_files',
    'pg_write_server_files', 'pg_execute_server_program' which
    allow an administrator to GRANT to a non-superuser role the ability to
    access server-side files or run programs through PostgreSQL (as the user
    the database is running as).  Having one of these roles allows a
    non-superuser to use server-side COPY to read, write, or with a program,
    and to use file_fdw (if installed by a superuser and GRANT'd USAGE on
    it) to read from files or run a program.

    The existing misc file functions are also changed to allow a user with
    the 'pg_read_server_files' default role to read any files on the
    filesystem, matching the privileges given to that role through COPY and
    file_fdw from above.

    Reviewed-By: Michael Paquier
    Discussion: https://postgr.es/m/20171231191939.GR2416%40tamriel.snowman.net

Three new [default roles](https://www.postgresql.org/docs/devel/static/default-roles.html)
have been added in version 11:

  * pg\_execute\_server\_program
  * pg\_read\_server\_files
  * pg\_write\_server\_files

The first one, pg\_execute\_server\_program, is as described in its name the
possibility to execute server-side program calls.  This is used in two places:

  * [COPY ... FROM PROGRAM](https://www.postgresql.org/docs/devel/static/sql-copy.html),
  which allows to execute a program which returns data into a pipe fed from
  or to the table involved.  An example of such a case is copying data from
  a server-side file which is compressed and cannot be parsed by default.
  This is a grammar supported down to Postgres 9.3.
  * [file\_fdw](https://www.postgresql.org/docs/10/static/file-fdw.html),
  which is a wrapper on top of the internal COPY protocol able to mimic
  what the parent command can to, which is available since version 10.

For example, with the foreign-data wrapper file\_fdw, a superuser can do
the following operation to copy some data to a table by executing a program.
Here is for example some data for a table which is compressed:

    $ gunzip < /path/to/data/data.gz
    1 foo
    2 bar
    3 foobar

Then using file\_fdw it is possible to directly feed on-the-fly a table from
this compressed on-disk data which is located server-side:

    =# CREATE EXTENSION file_fdw;
    CREATE EXTENSION
    =# CREATE SERVER data_server FOREIGN DATA WRAPPER file_fdw;
    CREATE SERVER
    =# CREATE FOREIGN TABLE compressed_data (
         a int,
         b text)
       SERVER data_server
       OPTIONS (
         program 'gunzip < /path/to/data/data.gz',
         delimiter ' ');
    =# SELECT * FROM compressed_data ;
     a |  b
    ---+------
     1 | foo
     2 | bar
     3 | hoge
    (3 rows)

This is not new and can already be done with Postgres 10, at the condition
that the user running those queries is a superuser.  The portion which is
new is this one, once a new user is involved.  Let's first create a user
as follows and then switch the session it:

    =# CREATE ROLE rogue_user LOGIN;
    CREATE ROLE
    =# GRANT USAGE ON FOREIGN server data_server to rogue_user;
    GRANT
    =# SET SESSION AUTHORIZATION rogue_user;
    SET
    => CREATE FOREIGN TABLE compressed_data (
         a int,
         b text)
       SERVER data_server
       OPTIONS (
         program 'gunzip < /path/to/data/data.gz',
         delimiter ' ');
    ERROR:  42501: only superuser or a member of the pg_execute_server_program
       role may specify the program option of a file_fdw foreign table
    LOCATION:  file_fdw_validator, file_fdw.c:280

One new part is this error message which involves the new default role, as
well as now the possibility to allow the user to define such a table
by granting to it pg\_execute\_server\_program.

    => RESET SESSION AUTHORIZATION;
    RESET
    =# GRANT pg_execute_server_program TO rogue_user;
	GRANT ROLE

Once this is done the previous CREATE TABLE query can be executed and
can be queried.

    =#  SET SESSION AUTHORIZATION rogue_user;
    SET
    => CREATE FOREIGN TABLE ...
    => SELECT * FROM compressed_datax;
     a |  b
	---+------
     1 | foo
     2 | bar
     3 | hoge
    (3 rows)

The second default role added is pg\_read\_server\_files, which can
be used for two things:

  * Server-side COPY FROM, which was a superuser-only restriction until
  version 10.
  * And more importantly access to *any* files on the server, which is
  a property not to ignore, and a really important thing to not forget
  when using this new default role.

The base path used by a process spawned in PostgreSQL is the data folder
itself, and up to PostgreSQL 10 the following restrictions apply, even
to *superusers* when it comes for example to read a file:

  * No absolute path can be used, except if it points to a file within
  the data folder or the log directory, which can be out of the main
  data folder.
  * Relative paths refer to the data folder as base point, and cannot
  look at files in parent directories.

In Postgres 11, those rules have changed a bit for superusers and roles
to which pg\_read\_server\_files is granted with the possibility to
read *any* files on the server the PostgreSQL instance has read access
to.  The firstly-described set of rules still applies for roles which
are not granted the power of pg\_read\_server\_files with only GRANT
access to dedicated system functions, like pg\_read\_file for example.

The last default role added is pg\_write\_server\_files, which has a
range more limited as it allows COPY TO to work with non-superuser
to which is granted the powers of this new default role, so that's
still useful for some applications where the server-side data loading
can be dedicated to roles external to superusers and administrators.
