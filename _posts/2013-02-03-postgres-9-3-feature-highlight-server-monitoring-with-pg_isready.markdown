---
author: Michael Paquier
lastmod: 2013-02-03
date: 2013-02-03 06:23:00+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-server-monitoring-with-pg_isready
title: 'Postgres 9.3 feature highlight - server monitoring with pg_isready'
categories:
- PostgreSQL-2
tags:
- 9.3
- pg_isready
- postgres
- postgresql
- monitoring

---

PostgreSQL 9.3 adds a new feature related to monitoring with the commit below.

    commit ac2e9673622591319d107272747a02d2c7f343bd
    Author: Robert Haas <rhaas@postgresql.org>
    Date:   Wed Jan 23 10:58:04 2013 -0500
    
    pg_isready
    
    New command-line utility to test whether a server is ready to
    accept connections.
    
    Phil Sorber, reviewed by Michael Paquier and Peter Eisentraut

Called pg\_isready, this allows to ping a wanted server to get a status of its activity. This module is a simple wrapper of PQping that can be called directly and customized with a set of options.

Here are the possible options.

    $ pg_isready --help
    pg_isready issues a connection check to a PostgreSQL database.
    
    Usage:
        pg_isready [OPTION]...
    
    Options:
    -d, --dbname=DBNAME      database name
    -q, --quiet              run quietly
    -V, --version            output version information, then exit
    -?, --help               show this help, then exit
    
    Connection options:
    -h, --host=HOSTNAME      database server host or socket directory
    -p, --port=PORT          database server port
    -t, --timeout=SECS       seconds to wait when attempting connection, 0 disables (default: 3)
    -U, --username=USERNAME  database username

This feature is really easy to use, for example in the case of a server online.

    $ pg_isready -p 5432 -h localhost
    localhost:5432 - accepting connections

For a server offline, sending no response back.

    $ pg_isready -p 5433 -h localhost
    localhost:5433 - no response

For a server rejecting connections.

    pg_isready -p 5432 -h $SERVER_IP
    $SERVER_IP:5432 - rejecting connections

The feature has also a quiet mode. So scripts can use the output value of pg\_isready to check the server activity. Once again with the previous examples.

    $ pg_isready -p 5432 -h localhost -q; echo $?
    0
    $ pg_isready -p 5433 -h localhost -q; echo $?
    2

0 is outputted for a server accepting connections, 2 is used in the case where no response comes back from the server. Then, 3 is the result if an internal error happens, like a wrong option specified. 1 corresponds to the case where connections are rejected.

It is honestly more intuitive to have such a wrapper in core than something that uses a query of the type "SELECT 1" to check the activity of a server. In summary, it is one of those little things that can make your life as a PostgreSQL user easier.
