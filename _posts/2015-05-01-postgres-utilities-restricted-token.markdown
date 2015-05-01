---
author: Michael Paquier
lastmod: 2015-05-01
date: 2015-05-01 13:25:33+00:00
layout: post
type: post
slug: postgres-utilities-restricted-token
title: 'Postgres utilities and restricted tokens on Windows'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- highlight
- windows
- token
- privilege
- administrator
- rights
- give up
- restricted

---

On Unix-Linux platforms, Postgres binaries are not authorized to run
as root use for security reasons when those utilities directly manipulate
files in the data directory. See for example initdb:

    initdb: cannot be run as root
    Please log in (using, e.g., "su") as the (unprivileged) user that will
    own the server process.

Or the backend binary:

    "root" execution of the PostgreSQL server is not permitted.
    The server must be started under an unprivileged user ID to prevent
    possible system security compromise.  See the documentation for
    more information on how to properly start the server.

On Windows as well, platform where everything is different, the error that
the "postgres" binary returns is a bit different but similar:

    Execution of PostgreSQL by a user with administrative permissions is not
    permitted.
    The server must be started under an unprivileged user ID to prevent
    possible system security compromises.  See the documentation for
    more information on how to properly start the server.

The PostgreSQL server cannot be logically started if it has administrator
privileges. But now, there is an exception for frontend utilities like
initdb, which can be run as a user with Administrator privileges by using
a restricted token ensuring that the process is being run under a secured
context (See [CreateRestrictedToken]
(https://msdn.microsoft.com/en-us/library/windows/desktop/aa446583%28v=vs.85%29.aspx)
refering to DISABLE\_MAX\_PRIVILEGE).

Most of the frontend utilities of Postgres make use of a restricted token,
but actually this was not the case of two of them, as [reported]
(http://www.postgresql.org/message-id/CAEB4t-NpXGiP5Bqvv3P+d+x=V4BqE+Awg+G7ennBn8icPXep_g@mail.gmail.com)
a couple of months back. The discussion regarding the bug report has resulted
in the following commit:

    commit: fa1e5afa8a26d467aec7c8b36a0b749b690f636c
    author: Andrew Dunstan <andrew@dunslane.net>
    date: Mon, 30 Mar 2015 17:07:52 -0400
    Run pg_upgrade and pg_resetxlog with restricted token on Windows

    As with initdb these programs need to run with a restricted token, and
    if they don't pg_upgrade will fail when run as a user with Adminstrator
    privileges.

    Backpatch to all live branches. On the development branch the code is
    reorganized so that the restricted token code is now in a single
    location. On the stable branches a less invasive change is made by
    simply copying the relevant code to pg_upgrade.c and pg_resetxlog.c.

    Patches and bug report from Muhammad Asif Naeem, reviewed by Michael
    Paquier, slightly edited by me.

On top of fixing the previous issue, this commit has added some infrastructure
by adding in libpqcommon a new API that frontend utilities can directly use
to fetch a restricted token on Windows, with a one-liner patch adding a call
to get\_restricted\_token(progname). An example of its use is for example
pg\_rewind that has begun to use it [here]
(http://git.postgresql.org/gitweb/?p=postgresql.git;a=commitdiff;h=8a06c36),
and this should be included in any Postgres utility that manipulates data
files for safety, particularly if this utility is aimed at running on Windows.
