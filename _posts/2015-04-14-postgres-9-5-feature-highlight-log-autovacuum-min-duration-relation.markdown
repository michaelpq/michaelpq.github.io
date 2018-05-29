---
author: Michael Paquier
lastmod: 2015-04-14
date: 2015-04-14 13:18:46+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-log-autovacuum-min-duration-relation
title: 'Postgres 9.5 feature highlight - log_autovacuum_min_duration at relation level'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.5
- vacuum
- log

---

[log\_autovacuum\_min\_duration]
(https://www.postgresql.org/docs/devel/static/runtime-config-autovacuum.html#GUC-LOG-AUTOVACUUM-MIN-DURATION)
is a system-wide parameter controlling a threshold from which autovacuum
activity is logged in the system logs. Every person who has already worked
on looking at a system where a given set of table is bloated has for sure
already been annoyed by the fact that even a high value of
log\_autovacuum\_min\_duration offers no guarantee in reducing log spams
of not-much-bloated tables whose autovacuum runtime takes more than the
threshold value, making its activity being logged (and this is after working
on such a lambda system that the author of this feature wrote a patch for
it). Postgres 9.5 is coming with a new feature allowing to control this
logging threshold at relation level, feature introduced by this commit:

    commit: 4ff695b17d32a9c330952192dbc789d31a5e2f5e
    author: Alvaro Herrera <alvherre@alvh.no-ip.org>
    date: Fri, 3 Apr 2015 11:55:50 -0300
    Add log_min_autovacuum_duration per-table option

    This is useful to control autovacuum log volume, for situations where
    monitoring only a set of tables is necessary.

    Author: Michael Paquier
    Reviewed by: A team led by Naoya Anzai (also including Akira Kurosawa,
    Taiki Kondo, Huong Dangminh), Fujii Masao.

This parameter can be set via [CREATE TABLE]
(https://www.postgresql.org/docs/devel/static/sql-createtable.html) or
[ALTER TABLE](https://www.postgresql.org/docs/9.4/static/sql-altertable.html),
with default value being the one defined by the equivalent parameter at
server-level, like that for example:

    =# CREATE TABLE vac_table (a int) WITH (log_autovacuum_min_duration = 100);
    CREATE TABLE
    =# ALTER TABLE vac_table SET (log_autovacuum_min_duration = 200);
    ALTER TABLE

Note that This parameter has no unit and cannot use any units like the
other relation-level options, and it has a default unit of milliseconds,
so after CREATE TABLE the autovacuum activity of relation vac\_table is
logged if its run has taken more than 100ms, and 200ms after ALTER TABLE.

Thinking wider, there are two basically cases where this parameter is useful,
an inclusive and an exclusive case:

  * when system-wide log\_autovacuum\_min\_duration is -1, meaning that all
  the autovacuum activity is ignored for all the relations, set this parameter
  to some value for a set of tables, and the autovacuum activity of this
  set of tables will be logged. This is useful to monitor how autovacuum
  is working on an inclusive set of tables, be it a single entry or more.
  * when willing to exclude the autovacuum runs of a set of tables with a
  value of log\_autovacuum\_min\_duration positive, simply set the value
  for each relation of this set at a very high value, like a value a single
  autovacuum is sure to not take, and then the autovacuum activity of this
  set of tables will be removed from the system logs.

In short words, this parameter is going to make life easier for any person
doing debugging of an application bloating tables, and just that is cool.
