---
author: Michael Paquier
lastmod: 2015-01-18
date: 2015-01-18 13:54:23+00:00
layout: post
type: post
slug: 2015-01-18-postgres-odbc-driver-libpq-govern-all
title: 'Postgres ODBC driver: libpq to govern them all'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- highlight
- odbc
- driver
- libpq
- dependency
- reduce
- sspi
- openssl
- ssl

---

Many improvements are being done in the ODBC driver for PostgreSQL these
days, one being for example the addition of more and more integrated
regression tests insuring the code quality. One feature particularly
interested has been committed these days and consists of the following
commit:

    commit: e85fbb24249ae81975b1b2e46da32479de0b58d6
    author: Heikki Linnakangas <heikki.linnakangas@iki.fi>
    date: Wed, 31 Dec 2014 14:49:20 +0200
    Use libpq for everything.

    Instead of speaking the frontend/backend protocol directly, use libpq's
    functions for executing queries. This makes it libpq a hard dependency, but
    removes direct dependencies to SSL and SSPI, and a lot of related code.

This feature can be defined in one single word: simplification. Before
discussing about it, see for example the cleanup that this has done in the
driver code in terms of numbers:

    $ git log -n1 e85fbb2 --format=format: --shortstat
    53 files changed, 1720 insertions(+), 8173 deletions(-)

Note the total size of the source code after this commit, which has been
reduced by a bit more than 10% in total, which is huge!

    # All code
    $ git ls-files "*.[c|h]" | xargs wc -l | tail -n1
    55998 total
	# Regression tests
    $ cd test/ && git ls-files "*.[c|h]" | xargs wc -l | tail -n1
    5910 total

Now, let's consider the advantages that this new feature has.

First of all, [libpq](http://www.postgresql.org/docs/devel/static/libpq.html)
is an in-core library of PostgreSQL managing communication with the backend
server that is well-maintained by the core developers of Postgres. Before doing
the all-libpq move in Postgres ODBC it was a soft dependency: the driver being
usable as well through SSPI, SSL or even nothing thanks to the additional code
it carried for managing directly the backend/frontend communication protocol,
while with libpq there are APIs directly usable for this purpose. So a large
portion of the simplification is related to that (and also to some code used
to manage communication socket and SSPI).

Hence, this move is an excellent thing particularly for the Windows installer
of Postgres ODBC because until now it needed to include a version of OpenSSL,
version that can be vulnerable depending on the issues found in it (remember
Heartbleed to convince yourself). So the driver msi installer needed an update
each time OpenSSL was dumped to a new version, making its maintenance more
frequent. Those updates are not needed when ODBC driver uses libpq as a
hard dependency, only PostgreSQL needing an update when a vulnerability is
found within OpenSSL for example.

What would be a next step then now that the driver side is more simple? Well,
more work on Postgres itself can be done. And this effort has begun with some
legwork done in the upcoming 9.5 to allow support of other SSL implementations
by making the infrastructure more pluggable with commit [680513a]
(http://git.postgresql.org/gitweb/?p=postgresql.git;a=commitdiff;h=680513a),
opening the door for things like [SChannel on Windows] 
(http://www.postgresql.org/message-id/53959E44.1070001@vmware.com), making
the existing Postgres installer even more pluggable, and more interesting by
letting users the choice in the dependencies a custom build uses.
