---
author: Michael Paquier
lastmod: 2017-02-13
date: 2017-02-13 06:50:43+00:00
layout: post
type: post
slug: postgres-10-pgpassfile-connection
title: 'Postgres 10 highlight - Password file paths as libpq connection parameter'
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
- connection
- string
- parameter
- pgpass
- file
- password
- environment
- variable
- alternative

---

Here is a feature for Postgres 10 that a couple of people will find useful
regarding the handling of
[password files](https://www.postgresql.org/docs/devel/static/libpq-pgpass.html):

    commit: ba005f193d88a8404e81db3df223cf689d64d75e
    author: Tom Lane <tgl@sss.pgh.pa.us>
    date: Tue, 24 Jan 2017 17:06:34 -0500
    Allow password file name to be specified as a libpq connection parameter.

    Formerly an alternate password file could only be selected via the
    environment variable PGPASSFILE; now it can also be selected via a
    new connection parameter "passfile", corresponding to the conventions
    for most other connection parameters.  There was some concern about
    this creating a security weakness, but it was agreed that that argument
    was pretty thin, and there are clear use-cases for handling password
    files this way.

    Julian Markwort, reviewed by Fabien Coelho, some adjustments by me

    Discussion: https://postgr.es/m/a4b4f4f1-7b58-a0e8-5268-5f7db8e8ccaa@uni-muenster.de

[Connection strings](https://www.postgresql.org/docs/9.6/static/libpq-connect.html#LIBPQ-CONNSTRING)
can be used to connect to a PostgreSQL instance and can be customized in many
ways to decide how the client should try to connect with the backend server.
The documentation offers a large [list](https://www.postgresql.org/docs/devel/static/libpq-connect.html#libpq-paramkeywords)
nicely documented, most of them being as well overridable using mapping
environment variables listed [here](https://www.postgresql.org/docs/devel/static/libpq-envars.html).

The commit above enables the possibility to override the position of a
password file directly using a path, without the need of an environment
variable. This is a major advantage for some class of users. For example
imagine the case where Postgres is used on a host shared by many users, where
trusted connections cannot be used even with local Unix domains path under the
control of a specific group or user because those users rely on default paths
like /tmp or default localhost (the limitation here being that pg_hba\.conf
assumes that "local" entries map to *all* local Unix domains). When creating
a service that links to PostgreSQL, monitored by some higher-level
application, this service may not be able to use the environment variables
at its disposal to find the path to a password file. While it is necessary
to hardcode somewhere the path to the password file, what is more a pain
is the extra logic needed to parse the password file in place and then use
its data directly in the connection string. The above commit makes all
this class of parsing problems completely disappear, and that's much welcome.

The environment variable PGPASSFILE is already at disposal to enforce at
session-level the path of the password file, and now the parameter called
"passfile" can be used directly in a connection string to enforce the
path where to find the user information, for a use like the following one:

    $ psql -d "passfile=/path/to/pgpass dbname=dbfoo" -U userfoo

This would simply attempt a connection to the instance at address localhost,
using database user "userfoo", on database "dbfoo". If the password file
specified in the connection string matches, then a lookup is done on it
to avoid input of any password needed. Note that no errors are reported
if the password file is missing, that the password file path cannot be a
symlink to something else and that it cannot have world or group permissions.
There is nothing new here compared to past versions of PostgreSQL, the same
checks applying as well on this new connection parameter.
