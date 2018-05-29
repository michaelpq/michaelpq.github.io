---
author: Michael Paquier
lastmod: 2015-04-04
date: 2015-04-04 13:01:22+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-pgctl-default-mode
title: 'Postgres 9.5 feature highlight - Default shutdown mode of pg_ctl to fast'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.5
- pg_ctl

---

This week, I wanted to share something that may impact many users of
Postgres, with this commit changing a behavior in a binary utility
that had for a long time been the same default:

    commit: 0badb069bc9f590dbc1306ccbd51e99ed81f228c
    author: Bruce Momjian <bruce@momjian.us>
    date: Tue, 31 Mar 2015 11:46:27 -0400
    pg_ctl:  change default shutdown mode from 'smart' to 'fast'

    Retain the order of the options in the documentation.

[pg\_ctl](https://www.postgresql.org/docs/devel/static/app-pg-ctl.html)
has three shutdown modes:

  * smart, the polite one, waits patiently for all the active clients
  connections to be disconnected before shutting down the server. This
  is the default mode for Postgres for ages.
  * immediate, the brute-force one, aborts all the server processes
  without thinking, leading to crash recovery when the instance is
  restarted the next time.
  * fast, takes an intermediate approach by rollbacking all the existing
  connections and then shutting down the server.

Simply, the "smart" mode has been considered the default because it is
the least distuptive, particularly it will wait for a backup to finish
before shutting down the server. It has been (justly) discussed that it
was not enough aggresive, users being sometimes surprised that a shutdown
requested can finish with a timeout because a connection has been for
example left open, hence the default has been switched to "fast".

This is not complicated litterature, however be careful if you had scripts
that relied on the default behavior of pg\_ctl when switching to 9.5,
particularly for online backups that will be immediately terminated at
shutdown with the new default.
