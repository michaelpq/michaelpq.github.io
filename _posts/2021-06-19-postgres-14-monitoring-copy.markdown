---
author: Michael Paquier
lastmod: 2021-06-19
date: 2021-06-19 01:48:55+00:00
layout: post
type: post
slug: postgres-14-monitoring-copy
title: 'Postgres 14 highlight - Monitoring for COPY'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 14
- copy
- monitoring

x---

When it comes to monitoring in PostgreSQL, progress reports, able to give
the state of an operation at a given point in time, exist since 9.6 and
[pg\_stat\_process\_vacuum](https://www.postgresql.org/docs/devel/monitoring-stats.html#MONITORING-STATS-VIEWS)
for VACUUM.  PostgreSQL 14 is adding a new feature in this area with
progress reporting for COPY, as of this
[commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=8a4f618):

    commit: 8a4f618e7ae3cb11b0b37d0f06f05c8ff905833f
    author: Tomas Vondra <tomas.vondra@postgresql.org>
    date: Wed, 6 Jan 2021 21:46:26 +0100
    Report progress of COPY commands

    This commit introduces a view pg_stat_progress_copy, reporting progress
    of COPY commands.  This allows rough estimates how far a running COPY
    progressed, with the caveat that the total number of bytes may not be
    available in some cases (e.g. when the input comes from the client).

    Author: Josef Šimánek
    Reviewed-by: Fujii Masao, Bharath Rupireddy, Vignesh C, Matthias van de Meent
    Discussion: https://postgr.es/m/CAFp7QwqMGEi4OyyaLEK9DR0+E+oK3UtA4bEjDVCa4bNkwUY2PQ@mail.gmail.com
    Discussion: https://postgr.es/m/CAFp7Qwr6_FmRM6pCO0x_a0mymOfX_Gg+FEKet4XaTGSW=LitKQ@mail.gmail.com

This was the initial commit of the feature, and it got improved in a second
[commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=9d2d457)
to have more information.

COPY can be long, very long depending on the amount of data to load with
users having no idea how the operation is going to last.  So more monitoring
capabilities in this area is welcome.  The state of operations can be tracked
in a new system view called
[pg\_stat\_progress\_copy](https://www.postgresql.org/docs/devel/progress-reporting.html#COPY-PROGRESS-REPORTING)
that returns one row per backend running a COPY.  Several fields are tracked
in that:

  * The PID of the backend running the operation.
  * The type of operation: COPY FROM, TO
  * The relation operated on, or just 0 if using a SELECT with COPY FROM.
  * The amount of data processed, thanks to the size of the rows aggregated
  each time a tuple is processed.
  * The number of tuples processed, or even skipped as an effect of a WHERE
  clause specified in COPY FROM.
  * The total amount of data from the original file of a COPY FROM.  This is
  not known if the data is provided through a pipe like stdin or psql's
  \copy, only with a plain COPY FROM with the file located in the same host
  as the instance of PostgreSQL running, as the backend uses stat() directly
  on the data file.

Let's take a simple example, first with COPY TO:

    =# CREATE TABLE copy_tab (a int, b text);
    CREATE TABLE
    =# INSERT INTO copy_tab SELECT generate_series(1, 10) AS a,
	  'a' ||  generate_series(1, 10) AS b;
    INSERT 0 10
    =# COPY copy_tab TO '/tmp/copy_tab_data.txt';
    COPY 10

Close to the end of the operation, reports look like that, with all rows
processed and the total amount of data in:

    =# SELECT relid::regclass, command, type, bytes_processed, tuples_processed
         FROM pg_stat_progress_copy;
      relid   | command | type | bytes_processed | tuples_processed
    ----------+---------+------+-----------------+------------------
     copy_tab | COPY TO | FILE |              52 |               10
    (1 row)

Now here is an example with COPY FROM with half the rows excluded:

    =# TRUNCATE copy_tab ;
    TRUNCATE TABLE
    =# COPY copy_tab FROM '/tmp/copy_tab_data.txt' WHERE a > 5;
    COPY 5

Reports would look like that with its operation close to its end, with
details about the number of tuples processed and the ones excluded by
the WHERE filtering:

    =# SELECT relid::regclass, command,
              type, bytes_processed, bytes_total,
              tuples_processed, tuples_excluded FROM pg_stat_progress_copy;
      relid   |  command  | type | bytes_processed | bytes_total | tuples_processed | tuples_excluded
    ----------+-----------+------+-----------------+-------------+------------------+-----------------
     copy_tab | COPY FROM | FILE |              52 |          52 |                5 |               5
    (1 row)

As mentioned above, sending the data through a pipe would give no
information about the total number of bytes expected to be treated:

    =# \copy copy_tab FROM '/tmp/copy_tab_data.txt' WHERE a > 5;
    COPY 5

Note how the type of the operation has changed, and that "bytes\_total"
reports 0:

     =# SELECT relid::regclass, command,
               type, bytes_processed, bytes_total,
               tuples_processed, tuples_excluded FROM pg_stat_progress_copy;
      relid   |  command  | type | bytes_processed | bytes_total | tuples_processed | tuples_excluded
    ----------+-----------+------+-----------------+-------------+------------------+-----------------
     copy_tab | COPY FROM | PIPE |              52 |           0 |                5 |               5
    (1 row)

As any of the existing progress reports, this only gives information about
the state of an operation at the moment the catalog is looked at, but doing
time estimations for the operation can easily be done with for example a
simple \watch command and INSERT SELECT into a custom table that stores the
catalog data or an external module doing the job, which requires some extra
efforts.
