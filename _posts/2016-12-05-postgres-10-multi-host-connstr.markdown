---
author: Michael Paquier
lastmod: 2016-12-05
date: 2016-12-05 06:20:53+00:00
layout: post
type: post
slug: postgres-10-multi-host-connstr
title: 'Postgres 10 highlight - Multiple hosts in connection strings'
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
- multiple
- host
- failure
- attempts

---

Client applications dependent on libpq can use
[connection strings](https://www.postgresql.org/docs/devel/static/libpq-connect.html#libpq-connstring)
to connect to a Postgres server, which is something present for ages.
Postgres 10 is introducing a new flavor in that by allowing applications
to define multiple connection points, for a feature introduced by the
[following commit](http://git.postgresql.org/pg/commitdiff/274bb2b38):

    commit: 274bb2b3857cc987cfa21d14775cae9b0dababa5
    author: Robert Haas <rhaas@postgresql.org>
    date: Thu, 3 Nov 2016 09:25:20 -0400
    libpq: Allow connection strings and URIs to specify multiple hosts.

    It's also possible to specify a separate port for each host.

    Previously, we'd loop over every address returned by looking up the
    host name; now, we'll try every address for every host name.

    Patch by me.  Victor Wagner wrote an earlier patch for this feature,
    which I read, but I didn't use any of his code.  Review by Mithun Cy.

The currently-present two formats are supported by this commit: plain string
with a pair of keyword and value separated by a character '=' as well as
connection URIs as defined by [RFC 3986](www.ietf.org/rfc/rfc3986.txt).

The main point of this feature is to be able to list a set of hosts as follows
for both formats (those are minimally-formatted strings):

    host=host1,host2
    host=host1,host2 port=port1,port2
    postgresql://host1,host2/
    postgresql://host1:port2,host2:port2/

As specified by the commit message, each host is tried in the order given
in the string until a connection is successful. When the host name specified
is not a host address, both IPv4 and IPv6 are tried depending on the support
available on the platform where Postgres is compiled (compilation flag
HAVE_IPV6), but there is nothing new in that.

There are a couple of things to be careful about though. First, when
specifying a list of hosts and a list of ports, the number of items defined
in each must be equal except if there is only one port number defined, or
libpq would complain as follows:

    $ psql -d "host=localhost port=5444,5433"
    psql: could not match 2 port numbers to 1 hosts
    $ psql -d "host=host1,host2,host3 port=5444,5433"
    psql: could not match 2 port numbers to 3 host

If one port value is defined with a list of host names, the same port is
used for all of them when attempting a connection. If the number of ports
defined is equal to the number of host names, connections will be tried
using the list of mapped couples for host names and ports. So, those commands
would try to move on:

    # Attempt to connect to each host with port 5445
    $ psql -d "host=host1,host2,host3 port=5445"
	# Attempt to connect to host1/5435, then host2/5434 and finally host3/5433
    $ psql -d "host=host1,host2,host3 port=5435,5434,5433"

Another set of properties to be aware of is that hostaddr does not support
multiple host addresses, so this command actually tries only one connection:

    $ psql -d "host=host1,host2,host3 hostaddr=127.0.0.1"
    psql: could not connect to server: Connection refused
        Is the server running on host "127.0.0.1" and accepting
        TCP/IP connections on port 5432?

Defining multiple port values with one host address results in an unmapping
error:

    $ psql -d "host=host1,host2,host3 hostaddr=127.0.0.1,127.0.0.2 port=5432,10000"
    psql: could not match 2 port numbers to 1 hosts

Unix domain sockets are supported as well as PGHOST. For example with the
following command, PGHOST being defined with two Unix socket directories,
two attempts are done.

    $ export PGHOST=/tmp2,/tmp3
    $ psql
    psql: could not connect to server: No such file or directory
        Is the server running locally and accepting
        connections on Unix domain socket "/tmp2/.s.PGSQL.5432"?
    could not connect to server: No such file or directory
        Is the server running locally and accepting
        connections on Unix domain socket "/tmp3/.s.PGSQL.5432"?

And the same rule for ports and host address stands as well: priority
is given to the host address if defined.
