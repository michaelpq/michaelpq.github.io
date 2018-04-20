---
author: Michael Paquier
lastmod: 2018-04-20
date: 2018-04-20 03:55:17+00:00
layout: post
type: post
slug: manipulate-checksum
title: 'Manipulating checksums of a cluster'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 11
- checksum

---

PostgreSQL 11 is releasing a small binary called
[pg\_verify\_checksums](https://www.postgresql.org/docs/devel/static/pgverifychecksums.html)
which is able to check if page-level checksums are in a sane state for
a cluster which has been cleanly shutdown (this is necessary so as not
not face checksum inconsistencies because of torn pages).

Thinking about it, it is not actually complicated to extend the tool in
such a way that it enables and disables checksum for an offline cluster,
which has been resulted in a tool that I called
[pg\_checksums](https://github.com/michaelpq/pg_plugins/tree/master/pg_checksums)
available here.  This can compile with PostgreSQL 11, as it is has been
integrated with the new set of routines which can be used if a data folder
allows read permissions for a group.  Note that it is not complicated to
make that work with past versions as well and requires a couple of minutes,
but I keep any code in this tree simple of any cross-version checks.

So, pg\_checksums gains a couple of options compared to its parent:

  * Addition of an --action option, which can be set to "verify" to do
  what pg\_verify\_checksums does, "enable" to enable checksums on
  a cluster, and "disable" to do the reverse operation.  "disable"
  costs nothing as it is just a matter of updating the control file
  of the cluster.  "enable" costs a lot as it needs to update all the
  page's checksums and then update the control file.  For both things
  a sync of the data folder is done.
  * Addition of a --no-sync option, which disables the final fsync calls
  in charge of making the switch durable.  This can be useful for automated
  testing environments.

So imagine that you have a cluster with checkums disabled, and stopped
cleanly, then here is how to enable checksums:

    $ pg_controldata -D $PGDATA | grep checksum
    Data page checksum version:           0
    $ pg_checksums --action enable -D $PGDATA
    Checksum operation completed
    Data checksum version: 0
    Files operated:  1224
    Blocks operated: 3684
    Enabling checksums in cluster
	$ pg_controldata -D $PGDATA | grep checksum
	Data page checksum version:           1

Then let's look at the state of the page checksummed:

    $ pg_checksums --action verify -D $PGDATA
    Checksum operation completed
    Data checksum version: 1
    Files operated:  1224
    Blocks operated: 3684
    Bad checksums:  0

And all looks good.  This is a tool I wanted for some time, which is
kept in the box for some upgrade scenarios where an existing cluster
was not initialized with checksums, or has been forgotten to be set so.

Note as well that Michael Banck has also released a similar version of
this tool which can be found [here](https://github.com/credativ/pg_checksums),
so the work has been done twice in parallel.  Note that this version is
compatible  with past PostgreSQL versions, which is something I am too
lazy to  maintain within
[pg\_plugins](https://github.com/michaelpq/pg_plugins).  Note that the
option interface is also slightly different, but the basics are the same.
And the name is funnily the same :)

And thanks to Magnus Hagander and Daniel Gustafsson who authored the
parent utility now in upstream code.
