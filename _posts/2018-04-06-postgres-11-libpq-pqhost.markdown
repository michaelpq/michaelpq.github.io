---
author: Michael Paquier
lastmod: 2018-04-06
date: 2018-04-06 13:57:11+00:00
layout: post
type: post
slug: postgres-11-libpq-pqhost
title: 'Postgres 11 highlight - Improvements of PQhost for libpq'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 11
- libpq

---

As the week ends, here is an explanation behind the following commit
which has changed a bit the way the libpq routine called PQhost
behaves:

    commit: 1944cdc98273dbb8439ad9b387ca2858531afcf0
    author: Peter Eisentraut <peter_e@gmx.net>
    date: Tue, 27 Mar 2018 12:32:18 -0400
    libpq: PQhost to return active connected host or hostaddr

    Previously, PQhost didn't return the connected host details when the
    connection type was CHT_HOST_ADDRESS (i.e., via hostaddr).  Instead, it
    returned the complete host connection parameter (which could contain
    multiple hosts) or the default host details, which was confusing and
    arguably incorrect.

    Change this to return the actually connected host or hostaddr
    irrespective of the connection type.  When hostaddr but no host was
    specified, hostaddr is now returned.  Never return the original host
    connection parameter, and document that PQhost cannot be relied on
    before the connection is established.

    PQport is similarly changed to always return the active connection port
    and never the original connection parameter.

    Author: Hari Babu <kommi.haribabu@gmail.com>
    Reviewed-by: Michael Paquier <michael@paquier.xyz>
    Reviewed-by: Kyotaro HORIGUCHI <horiguchi.kyotaro@lab.ntt.co.jp>
    Reviewed-by: David G. Johnston <david.g.johnston@gmail.com>

When it comes to PostgreSQL, compatibility matters, so changing a
routine's result in such a way which makes sense and which would
not be surprising to the end-user's application is difficult.
PQhost has a long story behind.  If you refer to the
[documentation](https://www.postgresql.org/docs/devel/static/libpq-status.html),
you can notice that it is aimed at returning the host name of the
connection used.  Now things get complicated, even more since Postgres
10, for two reasons:

  * A [connection string](https://www.postgresql.org/docs/devel/static/libpq-connect.html#LIBPQ-CONNSTRING)
  can specity "host", which can be a host name, an IP or even a Unix
  socket path, or "hostaddr", which can be set to a numeric IP address to
  save hostname lookups (that can matter for some environments).  When
  both "host" and "hostaddr" are specified, then hostaddr is used for
  the connection.
  * Since Postgres 10, a comma-separated list of "host" or "hostaddr"
  values can be specified to define multiple end points.  This can be
  useful for example when not caring about the connection end point
  with multiple standbys for a read-only connection.

On top of that comes PQhost, which should specify the host used for
the connection, but is that always really the case?

Note that it is possible to easily see the result of PQhost using this
configuration for psql which shows to which port and host a connection
happens using PQhost and PQport:

    \set PROMPT1 '[host=%M;port=%>]=%# '

Then let's use some connection strings and compare the results:

  * host=/tmp hostaddr=127.0.0.1
  * hostaddr=127.0.0.1
  * host=localhost,localhost hostaddr=127.0.0.1,127.0.0.1
  * hostaddr=127.0.0.1,127.0.0.1
  * host=/tmp,/tmp hostaddr=127.0.0.1,127.0.0.1

First using the implementation of PQhost in PostgreSQL 10, we get that
for the connection strings above:

  * "local"
  * "local"
  * "localhost,localhost"
  * "local"
  * "/tmp,/tmp"

When specifying one single "host" with one "hostaddr" as in the first
case, the result is consistent with the documentation: the connection
is done with "hostaddr" but PQhost returns the value corresponding to
the "host".  When using only one "hostaddr", then things begin to get
surprising: a "local" connection is defined but actually the connection
uses a numerical IP.  Things get even crazier when using multiple "host"
values, in which case a full list of those is returned as result.
If only using multiple "hostaddr", the result is surprising as well,
leading to a "local" connection.  So it is better to not count on the
result of PQhost in Postgres 10 when using multiple values.

The commit mentioned at the beginning of the post has nicely reworked
the inferface.  Here are the same results using at Postgres 11 or newer
versions:

  * "local"
  * "127.0.0.1"
  * "localhost"
  * "127.0.0.1"
  * "local"

Those results get more consistent, particularly:

  * When specifying only "hostaddr", then PQhost reports it.
  * When using multiple values for "host" or "hostaddr", then the
  real host connection is reported.

The new design is also more consistent with a couple of extra tweaks:

  * An empty value is returned if the host information cannot be
  built (say the connection is not completely established).
  * As in the past, a NULL connection causes the result to be NULL.
  * When using multiple "host" of "hostaddr" values, please make sure
  to check the status of the connection before referring to it.  If
  the connection is not established, then PQhost would return the first
  value from the comma-separated list so it cannot be relied on.
