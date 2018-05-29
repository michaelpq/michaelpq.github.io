---
author: Michael Paquier
lastmod: 2016-12-09
date: 2016-12-09 13:44:12+00:00
layout: post
type: post
slug: postgres-10-libpq-read-write
title: 'Postgres 10 highlight - read-write and read-only mode of libpq'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 10
- libpq
- connection

---

libpq is getting some improvements in its
[connection strings](https://www.postgresql.org/docs/devel/static/libpq-connect.html#libpq-connstring)
to define some properties that are expected from the backend server
thanks to the
[following commit](https://git.postgresql.org/pg/commitdiff/274bb2b38),
that will be part of Postgres 10:

    commit: 721f7bd3cbccaf8c07cad2707826b83f84694832
    author: Robert Haas <rhaas@postgresql.org>
    date: Tue, 29 Nov 2016 12:18:31 -0500
    libpq: Add target_session_attrs parameter.

    Commit 274bb2b3857cc987cfa21d14775cae9b0dababa5 made it possible to
    specify multiple IPs in a connection string, but that's not good
    enough for the case where you have a read-write master and a bunch of
    read-only standbys and want to connect to whichever server is the
    master at the current time.  This commit allows that, by making it
    possible to specify target_session_attrs=read-write as a connection
    parameter.

    [...]

    Victor Wagner and Mithun Cy.  Design review by Álvaro Herrera, Catalin
    Iacob, Takayuki Tsunakawa, and Craig Ringer; code review by me.  I
    changed Mithun's patch to skip all remaining IPs for a host if we
    reject a connection based on this new parameter, rewrote the
    documentation, and did some other cosmetic cleanup.

In short, a new parameter called
[target\_session\_attrs](https://www.postgresql.org/docs/devel/static/libpq-connect.html#libpq-connect-target-session-attrs)
is added, and it can use the following values:

  * "any", meaning that any kind of servers can be accepted. This is as
  well the default value.
  * "read-write", to disallow connections to read-only servers, hot standbys
  for example.

The strings using this parameter can have the following format, both normal
connection strings and URIs are of course supported:

    host=host1 target_session_attrs=any
    host=host1,host2 port=port1,port2 target_session_attrs=any
    postgresql://host1:port2,host2:port2/?target_session_attrs=read-write

When attempting for example to connect to a standby, libpq would complain
as follows:

    $ psql -d "postgresql://localhost:5433/?target_session_attrs=read-write"
    psql: could not make a writable connection to server "localhost:5433"

This feature finds its strength with for example a cluster in the shape
of a primary and one or more standbys. If a failover happens and a standby
is promoted and switches to be a primary, target\_session\_attrs can be
used in read-write mode with the addresses of *all* the nodes of the cluster
to allow the application to connect to a primary for read-write actions
or any nodes for read-only actions. Depending on the latency between nodes,
multiple attempts will be done so this method has a high chance to slow down
the connection creation to the cluster but this can be useful when looking for
read-only connections or read-write connections (this is useful as well with
synchronous\_commit set to remote\_apply on the Postgres backend with multiple
synchronous standys to get consistent reads across all the nodes). Imagine for
example the case of three nodes, one primary and two standbys, located at
respectively host1, host2 and host3. On failure, the standby host2 gets
promoted, and a new standby on host1 is created to rebalance the number of
nodes in the cluster. With a connection string defining all the host names,
defined as follows, all connection attempts can be enforced to be on the
primary or any nodes. So, this would enforce a connection where the current
primary is located:

    host=host1,host2,host3 target_session_attrs=read-write

And this string allows connections to any nodes:

    host=host1,host2,host3 target_session_attrs=any

This simplifies the logic at application level: there is no need for it
to know exactly which node is the primary and which ones are the standbys.
The cost though, is an increase in connection failures when using the
read-write mode, but that may be acceptable if the cluster is in a low-latency
environment.

One last thing to know is that this new parameter can be controlled by an
environment variable, PGTARGETSESSIONATTRS, which is useful to enforce the
default to read-write for certain sessions.

Also, as mentioned in the commit message that has been shortened a bit for
this post, this method is inspired by the Postgres JDBC driver, so many
applications rely on a similar logic already.
