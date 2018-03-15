---
author: Michael Paquier
lastmod: 2014-12-09
date: 2014-12-09 3:02:22+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-reindex-schema
title: 'Postgres 9.5 feature highlight - REINDEX SCHEMA'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- highlight
- 9.5
- reindex
- indexes
- catalog
- pg_catalog
- system
- schema
- table
- reshape
- corrupt
- fix

---

PostgreSQL 9.5 has added a new mode for [REINDEX]
(http://www.postgresql.org/docs/devel/static/sql-reindex.html) with this
commit:

    commit: fe263d115a7dd16095b8b8f1e943aff2bb4574d2
    author: Simon Riggs <simon@2ndQuadrant.com>
    date: Tue, 9 Dec 2014 00:28:00 +0900
    REINDEX SCHEMA

    Add new SCHEMA option to REINDEX and reindexdb.

    Sawada Masahiko

    Reviewed by Michael Paquier and Fabrízio de Royes Mello

Up to 9.4, REINDEX is able to run on different things:

  * INDEX, to reindex a given index.
  * TABLE, to reindex entirely a table, including its underlying toast
  index if there is a toast table on it.
  * DATABASE, to reindex all the relations of the database user is
  currently connected to, including catalog tables.
  * SYSTEM, to reindex all the system catalogs.

A couple of things to note though:

  * Indexes reindexed are locked with a strong exclusive lock, preventing
  any other session to touch it.
  * Parent tables are locked with a share lock
  * DATABASE and SYSTEM cannot run in a transaction, and process tables
  one-by-one, pg_class being run first as REINDEX updates it (this last
  point is an implementation detail, not mentioned in the docs).

The new mode for SCHEMA mixes those things, but behaves similarly to
DATABASE and SYSTEM, for a schema:

  * It cannot run in a transaction.
  * Each table of the schema is processed one-by-one
  * pg_class is reindexed first only if pg\_catalog is processed.

That's actually what you can find here, note first that pg\_class is at the
top of the relations indexed.

    =# REINDEX SCHEMA pg_catalog;
    NOTICE:  00000: table "pg_catalog.pg_class" was reindexed
    LOCATION:  ReindexObject, indexcmds.c:1942
    [...]
    NOTICE:  00000: table "pg_catalog.pg_depend" was reindexed
    LOCATION:  ReindexObject, indexcmds.c:1942
    REINDEX

And that this operation is non-transactional:

    =# BEGIN;
    BEGIN
    =# REINDEX SCHEMA pg_catalog;
    ERROR:  25001: REINDEX SCHEMA cannot run inside a transaction block
    LOCATION:  PreventTransactionChain, xact.c:2976

A last thing to note is that a user that has no access on a schema will
logically not be able to run REINDEX on it.

    =# CREATE USER foo;
    CREATE ROLE
    =# SET SESSION AUTHORIZATION foo;
    SET
    => REINDEX SCHEMA public;
    ERROR:  42501: must be owner of schema public
    LOCATION:  aclcheck_error, aclchk.c:3376

This feature is particularly helpful when for example working on a server
that has multiple schemas when it is wanted to reindex some multiple
relations on a single schema as it makes unnecessary the step to list all
the relations or to play with a custom function. It presents as well the
advantage it avoids taking successive locks on all the objects when doing
the work database-wide.
