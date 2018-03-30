---
author: Michael Paquier
lastmod: 2015-06-07
date: 2015-06-07 11:52:22+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-system-view-ssl-info
title: 'Postgres 9.5 feature highlight - pg_stat_ssl, information about SSL connections'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.5
- view
- ssl
- security

---

Today's highlight is about a new system view that will land in Postgres 9.5,
that has been introduced by this commit:

    commit: 9029f4b37406b21abb7516a2fd5643e0961810f8
    author: Magnus Hagander <magnus@hagander.net>
    date: Sun, 12 Apr 2015 19:07:46 +0200
    Add system view pg_stat_ssl

    This view shows information about all connections, such as if the
    connection is using SSL, which cipher is used, and which client
    certificate (if any) is used.

    Reviews by Alex Shulgin, Heikki Linnakangas, Andres Freund & Michael
    Paquier


[pg\_stat\_ssl](http://www.postgresql.org/docs/devel/static/monitoring-stats.html#PG-STAT-SSL-VIEW)
is a system view showing statistics about the SSL usage of a given
connection, with one row per connection. The view is shaped as follows,
with information about if SSL is enabled, what is the version used, the
cipher, etc.

    =# \d pg_stat_ssl
       View "pg_catalog.pg_stat_ssl"
       Column    |  Type   | Modifiers
    -------------+---------+-----------
     pid         | integer |
     ssl         | boolean |
     version     | text    |
     cipher      | text    |
     bits        | integer |
     compression | boolean |
     clientdn    | text    |

SSL is not by default enabled in a Postgres build, even if most of the
versions of Postgres distributed in many OSes do use it. Still, if the switch
--with-openssl has not been used at configure all the connections will
be reported with NULL columns, and SSL of course is reported as disabled.
If SSL is disabled on the server on the server, this system view reports
the same information:

    =# SELECT * FROM pg_stat_ssl;
      pid  | ssl | version | cipher | bits | compression | clientdn
    -------+-----+---------+--------+------+-------------+----------
     12533 | f   | null    | null   | null | null        | null
    (1 row)

Now, when SSL is enabled on a server, one row is reported per connection.
Here is for example the case of two connections currently running on a
server, one using SSL to connect, and another not using SSL:

    =# SHOW ssl;
     ssl
    -----
     on
    (1 row)
    =# SELECT ssl, version, bits, compression FROM pg_stat_ssl;
     ssl | version | bits | compression
    -----+---------+------+-------------
     t   | TLSv1.2 |  256 | t
     f   | null    | null | null
    (2 rows)

As the PID can be used with pg\_stat\_ssl, be sure to join it with other
system relations like pg\_stat\_activity to get useful information for
given connections.
