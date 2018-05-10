---
author: Michael Paquier
lastmod: 2018-05-10
date: 2018-05-10 02:01:40+00:00
layout: post
type: post
slug: postgres-11-superuser-rewind
title: 'Postgres 11 highlight - Removing superuser dependency for pg_rewind'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 11
- rewind
- superuser

---

The following commit adds a new feature which is part of Postgres 11, and
matters a lot for a couple of tools:

    commit: e79350fef2917522571add750e3e21af293b50fe
    author: Stephen Frost <sfrost@snowman.net>
    date: Fri, 6 Apr 2018 14:47:10 -0400
    Remove explicit superuser checks in favor of ACLs

    This removes the explicit superuser checks in the various file-access
    functions in the backend, specifically pg_ls_dir(), pg_read_file(),
    pg_read_binary_file(), and pg_stat_file().  Instead, EXECUTE is REVOKE'd
    from public for these, meaning that only a superuser is able to run them
    by default, but access to them can be GRANT'd to other roles.

    Reviewed-By: Michael Paquier
    Discussion: https://postgr.es/m/20171231191939.GR2416%40tamriel.snowman.net

This is rather a simple thing: a set of in-core functions like using a
hardcoded superuser check to make sure that they do not run with unprivileged
user rights.  For the last couple of releases, an effort has been made to
remove those hardcoded checks so as one can GRANT execution access to a couple
or more functions so as actions which would need a full superuser (a user
who theoritically can do anything on the cluster and administers it), are
delegated to extra users with rights limited to those actions.

This commit, while making lookups to the data directory easier, is actually
very useful for [pg\_rewind](https://www.postgresql.org/docs/devel/static/app-pgrewind.html)
as it removes the need of having a database superuser in order to perform
the rewind operation when the source server is up and running.

In order to get to this state, one can create a dedicated user and then
grant execution to a subset of functions, which can be done as follows:

    CREATE USER rewind_user LOGIN;
    GRANT EXECUTE ON function pg_catalog.pg_ls_dir(text, boolean, boolean) TO rewind_user;
    GRANT EXECUTE ON function pg_catalog.pg_stat_file(text, boolean) TO rewind_user;
    GRANT EXECUTE ON function pg_catalog.pg_read_binary_file(text) TO rewind_user;
    GRANT EXECUTE ON function pg_catalog.pg_read_binary_file(text, bigint, bigint, boolean) TO rewind_user;

Once run, then this new database user "rewind\_user" will be able to run
pg\_rewind without superuser rights, which matters for a lot of deployments
as restricting superuser access to a cluster as much as possible is a common
security policy.  Note that pg\_dump is able to dump ACLs on system functions
since 9.6, so once put in place those policies remain in logical backups.
