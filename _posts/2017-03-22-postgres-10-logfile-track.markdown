---
author: Michael Paquier
lastmod: 2017-03-22
date: 2017-03-22 06:30:45+00:00
layout: post
type: post
slug: postgres-10-logfile-track
title: 'Postgres 10 highlight - Tracking of current logfiles'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- 10
- feature
- highlight
- log
- file
- tracking
- current
- syslog
- stderr
- csvlog

---

The [following feature]( http://git.postgresql.org/pg/commitdiff/19dc233c32f2900e57b8da4f41c0f662ab42e080)
has landed in Postgres 10 to help system administrators:

    commit: 19dc233c32f2900e57b8da4f41c0f662ab42e080
    author: Robert Haas <rhaas@postgresql.org>
    date: Fri, 3 Mar 2017 11:43:11 +0530
    Add pg_current_logfile() function.

    The syslogger will write out the current stderr and csvlog names, if
    it's running and there are any, to a new file in the data directory
    called "current_logfiles".  We take care to remove this file when it
    might no longer be valid (but not at shutdown).  The function
    pg_current_logfile() can be used to read the entries in the file.

    Gilles Darold, reviewed and modified by Karl O.  Pinc, Michael
    Paquier, and me.  Further review by Álvaro Herrera and Christoph Berg.

When "stderr" or "csvlog" is defined as log\_destination, there is no real
way to know to which PostgreSQL backends are writing to for most users. There
are configurations where this can be guessed automatically, for example
by tweaking log\_filename to use only a day or a month number, and then
have some client application layer guess what is currently the file being
written to based on the current data, but this adds an extra complexity by
having a dependency between an upper application layer and a setting
value in PostgreSQL.

The above patch, as mentioned in the commit message, shows up what are
the current files where logs are being written depending on the log
destination defined. Once run, it shows the file currently in use:

    =# SELECT pg_current_logfile();
               pg_current_logfile
    -----------------------------------------
     pg_log/postgresql-2017-03-22_151520.log
    (1 row)

This function actually parses a file in $PGDATA/current\_logfiles that
gets updated each time a log file is rotated, or when parameters are reloaded
and that there is a modification of the log destinations, the first
entry showing up if no argument is given. Note as well that the entry for
"stderr" is generated first, and then goes the one of "csvlog". So the
order of things writtent in current\_logfiles is pre-defined and does not
depend on the order of destinations defined in log\_destination.

An extra argument can be used as well, "csvlog" or "stderr" to get what is
the file in use for those log destinations:

    =# SELECT pg_current_logfile('stderr');
               pg_current_logfile
    -----------------------------------------
     pg_log/postgresql-2017-03-22_151520.log
    (1 row)
    =# SELECT pg_current_logfile('csvlog');
               pg_current_logfile
    -----------------------------------------
     pg_log/postgresql-2017-03-22_151520.csv
    (1 row)

Note that this function access is forbidden by default to non-superusers
but the access can be granted. Note also that the value of log\_directory,
which is a superuser-only parameter, is used as prefix of the result
returned. So granting the access of this function leaks a bit of
superuser-only information.
