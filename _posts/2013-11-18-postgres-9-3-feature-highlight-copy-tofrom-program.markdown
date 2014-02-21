---
author: Michael Paquier
comments: true
lastmod: 2013-11-18
date: 2013-11-18 04:27:43+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-copy-tofrom-program
title: 'Postgres 9.3 feature highlight: COPY TO/FROM PROGRAM'
categories:
- PostgreSQL-2
tags:
- 9.3
- compression
- copy
- curl
- data
- database
- feature
- from
- gzip
- input
- json
- open source
- output
- plpgsql
- postgres
- postgresql
- program
- separator
- to
- treat
---
Postgres 9.3 brings a new option for [COPY](http://www.postgresql.org/docs/devel/static/sql-copy.html) allowing to pipe data with an external program, both in input and output. This feature has been added in the following commit:

    commit 3d009e45bde2a2681826ef549637ada76508b597
    Author: Heikki Linnakangas
    Date: Wed Feb 27 18:17:21 2013 +0200

    Add support for piping COPY to/from an external program.
 
    This includes backend "COPY TO/FROM PROGRAM '...'" syntax, and corresponding
    psql \copy syntax. Like with reading/writing files, the backend version is
    superuser-only, and in the psql version, the program is run in the client.
 
    In the passing, the psql \copy STDIN/STDOUT syntax is subtly changed: if
    the stdin/stdout is quoted, it's now interpreted as a filename. For example,
    "\copy foo from 'stdin'" now reads from a file called 'stdin', not from
     standard input. Before this, there was no way to specify a filename called
    stdin, stdout, pstdin or pstdout.
 
    This creates a new function in pgport, wait_result_to_str(), which can
    be used to convert the exit status of a process, as returned by wait(3),
    to a human-readable string.
 
    Etsuro Fujita, reviewed by Amit Kapila.

This brings a new universe of possibility to manipulate or fetch data out of a table directly on the server.

Here is for example how to modify some data on the fly using this feature:

    =# COPY (SELECT 1, 2) TO PROGRAM 'sed -e "s/,/:/" > ~/test.txt' DELIMITER ',';
    COPY 1
    =# \q
    $ cat ~/test.txt
    1:2

Well...

And another example using awk:

    =# COPY (select 1, 2) TO PROGRAM 'awk -F '','' ''{print $NF}'' > ~/test.txt' DELIMITER ',';
    COPY 1
    =# \q
    $ cat test.txt
    2

Most of the uses you could imagine with COPY TO PROGRAM would involve either data manipulation or post-processing. Data manipulation would occur most of the time directly on the database server side for performance though, but you can actually do a couple of extra things like data compression on the fly, the only thing to remember with TO PROGRAM is that the data is *piped* to a program. So for example with gzip.

    =# COPY (SELECT 1, 2) TO PROGRAM 'gzip > ~/my_data.zip' DELIMITER ',';
    COPY 1
    =# \q
    $ gunzip < ~/my_data.zip
    1,2

This is pretty cool actually, and will save a couple of lines on custom scripts.

Note that process will fail if the program command exists with a non-zero error code:

    =# COPY (SELECT 1, 2) TO PROGRAM '/bin/false' DELIMITER ',';
    ERROR: XX000: program "/bin/false" failed
    DETAIL: child process exited with exit code 1
    LOCATION: ClosePipeToProgram, copy.c:1451

Now let's have a look at something that has far more potential for Postgres in my opinion: COPY FROM PROGRAM. The interest of this new feature is that it can do pre-processing as well as automatize the way data is pulled to your database (particularly useful in a stored procedure when you want to grab a bunch of data files that are identified with an ID or something similar). I find this particularly interesting with for example JSON data that you can find on the net easily, and even more with [JSON operators](http://michael.otacoo.com/postgresql-2/postgres-9-3-feature-highlight-json-operators/), [JSON parsing functions](http://michael.otacoo.com/postgresql-2/postgres-9-3-feature-highlight-json-parsing-functions/) and [JSON data generation functions](http://michael.otacoo.com/postgresql-2/postgres-9-3-feature-highlight-json-data-generation/) introduced in 9.3 as all those features combined allow you to do all the data analysis cycle directly on the Postgres server.

To finish this post, here is a short example of COPY FROM PROGRAM using some JSON data of [Open Weather Map](http://openweathermap.org/). First here is how to copy the latest weather data of Tokyo using curl directly into a Postgres table.

    =# CREATE TABLE weather_json (cities json);
    CREATE TABLE
    =# COPY weather_json FROM PROGRAM 'curl http://api.openweathermap.org/data/2.5/weather?q=Tokyo';
    COPY 1
    =# SELECT cities->'name' FROM weather_json;
     ?column?
    ----------
      "Tokyo"
    (1 row)

Then... It is let as an exercise to the reader to play with this data using the new JSON features of 9.3. The description of this JSON data is available [here](http://bugs.openweathermap.org/projects/api/wiki/Weather_Data). So why not trying to automatize the fetch of the weather data from many cities using some stored procedure or get some daily statistics after treating the data? Have fun!
