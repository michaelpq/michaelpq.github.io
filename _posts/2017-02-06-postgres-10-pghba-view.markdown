---
author: Michael Paquier
lastmod: 2017-02-06
date: 2017-02-06 06:04:24+00:00
layout: post
type: post
slug: postgres-10-pghba-view
title: 'Postgres 10 highlight - System view for pg_hba.conf'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 10
- connection
- security

---

Last week the following commit has landed in Postgres 10 code tree, something
that many users of servers with complicated connection policies will find
useful:

    commit: de16ab7238888b16825ad13f0bbe123632915e9b
    author: Tom Lane <tgl@sss.pgh.pa.us>
    date: Mon, 30 Jan 2017 18:00:26 -0500
    Invent pg_hba_file_rules view to show the content of pg_hba.conf.

    This view is designed along the same lines as pg_file_settings, to wit
    it shows what is currently in the file, not what the postmaster has
    loaded as the active settings.  That allows it to be used to pre-vet
    edits before issuing SIGHUP.  As with the earlier view, go out of our
    way to allow errors in the file to be reflected in the view, to assist
    that use-case.

    (We might at some point invent a view to show the current active settings,
    but this is not that patch; and it's not trivial to do.)

    Haribabu Kommi, reviewed by Ashutosh Bapat, Michael Paquier, Simon Riggs,
    and myself

    Discussion: https://postgr.es/m/CAJrrPGerH4jiwpcXT1-46QXUDmNp2QDrG9+-Tek_xC8APHShYw@mail.gmail.com

[pg\_hba.conf](https://www.postgresql.org/docs/devel/static/auth-pg-hba-conf.html)
is the central configuration of PostgreSQL controlling access policies,
being in charge of holding rules to move on with authorization attempts using
one protocol or another depending on the user and the database names given
by the client (replication connection being a bit different though with WAL
sender processes spawning on an instance). Firewalls likely stand on top
of any PostgreSQL instance (in a perfect world) to avoid any connection
attempts from certain range of addresses, and pg\_hba.conf is here to give
a second layer of checks at a lower level for SSL, PAM, password
authentication, etc.

The commit above adds a system view that gives at SQL-level access to the
data of pg\_hba.conf. This new view is named
[pg\_hba\_file\_rules](https://www.postgresql.org/docs/devel/static/view-pg-hba-file-rules.html)
and provides all the information that administrators have filled in this
file, like the line number of the entry, its type or its options. Here
is for example the output on a cluster initialized with initdb
--auth-local=trust:

    =# SELECT line_number, type, database, user_name, address, auth_method
       FROM pg_hba_file_rules;
     line_number | type  | database | user_name |  address  | auth_method
    -------------+-------+----------+-----------+-----------+-------------
              84 | local | {all}    | {all}     | null      | trust
              86 | host  | {all}    | {all}     | 127.0.0.1 | trust
              88 | host  | {all}    | {all}     | ::1       | trust
    (3 rows)


Note that database and user names that are included using files with '@' are
directly parsed in the view. So for example imagine the following entry in
pg\_hba.conf:

    # TYPE  DATABASE        USER            ADDRESS                 METHOD
    host    all             @names          ::1/128                 trust

And the file $PGDATA/names with the following content:

    foo_user,foo_user2

Then this shows up in the systen view as deparsed, and without the file path
defined in the entry:

    =# SELECT line_number, type, database, user_name, address, auth_method, error
       FROM pg_hba_file_rules WHERE line_number = 88;
     line_number | type | database |      user_name       | address | auth_method | error
    -------------+------+----------+----------------------+---------+-------------+-------
              88 | host | {all}    | {foo_user,foo_user2} | ::1     | trust       | null
    (1 row)

Something that makes this feature very powerful is the error field that is
present, here to track problems with each hba entry after a reload of the
server. For example, taking the previous case of a file included, but this
time without a file, here is what the system view shows after a reload of
the rules:

    =# SELECT line_number, error FROM pg_hba_file_rules WHERE line_number = 88;
     line_number |                                                         error
    -------------+------------------------------------------------------------------------------------------------------
              88 | could not open secondary authentication file "@names" as "/to/data/names": No such file or directory
    (1 row)

This allows administrators to get a quick look at what is wrong in
pg\_hba.conf and fixing it as necessary, which is really helpful for
maintenance tasks and when defining an incorrect set of options depending
on the dependencies of the build of Postgres used.

Of course, the access to this view is disabled by default to any
non-superusers, but an administrator can enable its access to any users
are there are no superuser checks embedded in the code.
