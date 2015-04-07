---
author: Michael Paquier
date: 2011-02-28 13:10:48+00:00
layout: page
type: page
slug: postgres
title: 'PostgreSQL'
tags:
- postgres
- postgresql
- community
- development
- bug
- maintenance
- project
- extension
- blog
- involvement
- support
- knowledge
- distribution
---
[PostgreSQL](http://www.postgresql.org) is the world's most advanced open
source database. It offers many features and is used in many production
systems worldwide so feel free to have a look at [its documentation]
(http://www.postgresql.org/docs/devel/static/) and get a grasp of what it
can do and with its active community it can actually do a lot.

### Activities

As a community member, on top of maintaining this blog, here are the things
I try to keep up with:

  * Patch submission and review
  * Involvement in hackers discussion, with sometimes participation in
  some other mailing lists
  * Participation in conferences, involvement in Japanese community
  * Sometimes on IRC...
  * Test machine maintenance in [Postgres buildfarm]
  (http://buildfarm.postgresql.org/)
  * Some development activities
   * [Dev postgres](https://github.com/michaelpq/postgres), a mirror of
   vanilla with only master branch and a set of patches in development
   * [pg\_arman](https://github.com/michaelpq/pg_arman), backup and
   recovery manager
   * [pg\_plugins](https://github.com/michaelpq/pg_plugins), some background
   workers that can be used as a base for more complex implementations

### TODO items

  * Check pg_usleep calls in checkpointer.
  * FIXME in prepare.c regarding the fact that parse analysis modifies the
  raw query tree, and it shouldn't.
  * Refactor relation options now in CREATE TABLE into a separate section
  in documentation, presumably "Relation Options" in "Server Configuration"
  with a sub-section for tables, and another for indexes.
  * Support for TAP tests on [Windows]
  (http://www.postgresql.org/message-id/CAB7nPqTQwphkDfZP07w7yBnbFNDhW_JBAMyCFAkarE2VWg8irQ@mail.gmail.com)
  * [Support for replication, archiving, PITR test suite, using TAP tests]
  (http://www.postgresql.org/message-id/CAB7nPqTf7V6rswrFa=q_rrWeETUWagP=h8LX8XAov2Jcxw0DRg@mail.gmail.com)
   * Add tests for recovery_target_action
   * Add test for reply delay with a 2PC transaction
   * Add test for replication slot with change receiver using replication
   interface (now only the SQL one is tested).
  * [Incorrect and missing SetStatusService calls for pg_ctl stop]
  (http://www.postgresql.org/message-id/20141028070241.2593.58180@wrigleys.postgresql.org)
  * [Compiler warnings for MinGW]
  (http://www.postgresql.org/message-id/CAMkU=1zCdP7YxX9HFeGihpqfnvJuzkQxZCnUSUL-wcberkmCcA@mail.gmail.com)
  * [PQExec hangs on OOM]
  (http://www.postgresql.org/message-id/547480DE.4040408@vmware.com)
  * [Ctrl-C causing server to stop automatically on Windows]
  (http://www.postgresql.org/message-id/lagpal$86e$1@ger.gmane.org)
  * [pg\_ctl does not correctly honor "DETACHED_PROCESS"]
  (http://www.postgresql.org/message-id/53759381.4000205@cubiclesoft.com)
