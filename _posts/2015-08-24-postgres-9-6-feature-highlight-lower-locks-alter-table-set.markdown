---
author: Michael Paquier
lastmod: 2015-08-24
date: 2015-08-24 14:06:56+00:00
layout: post
type: post
slug: postgres-9-6-feature-highlight-lower-locks-alter-table-set
title: 'Postgres 9.6 feature highlight - Lock reductions for ALTER TABLE SET'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- highlight
- 9.6
- lock
- reduction
- alter
- table
- set
- parameter
- vacuum
- autovacuum
- autoanalyze
- analyze

---

[ALTER TABLE](http://www.postgresql.org/docs/devel/static/sql-altertable.html)
has been known for many years in the Postgres ecosystem as being a command
taking systematically an ACCESS EXCLUSIVE lock on the relation being modified,
preventing all operations on the relation in parallel. Those locks are getting
more and more relaxed, with for example in Postgres 9.4 the following commands
that got improvements:

  * VALIDATE CONSTRAINT
  * CLUSTER ON
  * SET WITHOUT CLUSTER
  * ALTER COLUMN SET STATISTICS
  * ALTER COLUMN SET and ALTER COLUMN RESET for attribute options

In 9.5 as well those commands have been improved:

  * ENABLE TRIGGER and DISABLE TRIGGER
  * ADD CONSTRAINT FOREIGN KEY

Now, Postgres 9.6, which is currently in development, brings in more lock
reduction, with the following commit:

    commit: 47167b7907a802ed39b179c8780b76359468f076
    author: Simon Riggs <simon@2ndQuadrant.com>
    date: Fri, 14 Aug 2015 14:19:28 +0100
    Reduce lock levels for ALTER TABLE SET autovacuum storage options

    Reduce lock levels down to ShareUpdateExclusiveLock for all
    autovacuum-related relation options when setting them using ALTER TABLE.

    Add infrastructure to allow varying lock levels for relation options in
    later patches. Setting multiple options together uses the highest lock
    level required for any option. Works for both main and toast tables.

    Fabrízio Mello, reviewed by Michael Paquier, mild edit and additional
    regression tests from myself

Code speaking, ALTER TABLE SET has been improved to be able to define
different types of locks depending on the parameter touched, and in the
case of this commit all the parameters tuning autovacuum and auto-analyze
at relation level have been updated to use SHARE UPDATE EXCLUSIVE LOCK.
In short, this allows read as well as write operations to occur in parallel
of the ALTER TABLE, something that will definitely help leveraging activity
bloat on such relations.

Note as well that when multiple subcommands are used, the stronger lock
of the whole set is taken for the duration of the ALTER TABLE command.
So for example, should an update on the parameter fillfactor be mixed
with a modification of autovacuum\_enabled, an ACCESS EXCLUSIVE lock will
be taken on the relation instead of a SHARE UPDATE EXCLUSIVE lock. ALTER
TABLE uses the following set of locks, and those having a monotonic
relationship it is possible to establish a hierarchy of them, the strongest
one being the first listed here:

  * ACCESS EXCLUSIVE LOCK
  * SHARE ROW EXCLUSIVE LOCK
  * SHARE UPDATE EXCLUSIVE LOCK

Hence be sure to read the online documentation when planning to combine
multiple subcommands with ALTER TABLE, all the details are there.
