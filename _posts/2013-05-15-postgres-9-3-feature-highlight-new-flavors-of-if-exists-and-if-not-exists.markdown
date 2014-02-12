---
author: Michael Paquier
comments: true
date: 2013-05-15 11:51:07+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-new-flavors-of-if-exists-and-if-not-exists
title: 'Postgres 9.3 feature highlight: new flavors of IF EXISTS and IF NOT EXISTS'
wordpress_id: 1889
categories:
- PostgreSQL-2
tags:
- '9.3'
- alter
- create
- database
- DDL
- drop
- existence
- function
- if exists
- if not exists
- language
- object
- open source
- operator
- postgres
- postgresql
- role
- table
- trigger
- user
---

IF EXISTS and IF NOT EXISTS are clauses allowing to return a notice message instead of an error if a DDL query running on a given object already exists or not depending on the DDL action done. If a given query tries to create an object when IF NOT EXISTS is specified, a notice message is returned to client if the object has already been created and nothing is done on server side. If the object is altered or dropped when IF EXISTS is used, a notice message is returned back to client if the object does not exist and nothing is done. 

Here is what simply happens when a table that exists is created:

    postgres=# CREATE TABLE IF NOT EXISTS aa (a int);
    CREATE TABLE
    postgres=# CREATE TABLE IF NOT EXISTS aa (a int);
    NOTICE:  relation "aa" already exists, skipping
    CREATE TABLE

Similarly, when dropping this table based on its existence.

    postgres=# DROP TABLE IF EXISTS aa;
    DROP TABLE
    postgres=# DROP TABLE IF EXISTS aa;
    NOTICE:  table "aa" does not exist, skipping
    DROP TABLE

Prior to 9.3, PostgreSQL already proposed this feature with many objects: tables, index, functions, triggers, language, etc. Such SQL extensions are useful when running several times the same script several times and avoiding errors on environments already installed.
  
9.3 introduces some new flavors of IF [NOT] EXISTS completing a bit more the set of objects already supported.

  * CREATE SCHEMA [IF NOT EXISTS]
  * ALTER TYPE ADD VALUE [IF NOT EXISTS]
  * Extension of DROP TABLE IF EXISTS such as it succeeds if the specified schema does not exists

Note also that the new materialized views are also supported with IF [NOT] EXISTS for CREATE, ALTER and DROP.

The extension of CREATE SCHEMA with IF NOT EXISTS is pretty simple. Similarly to the other objects, command succeeds if the schema already exists and a notice message about the existence of schema is sent back to client.

    postgres=# CREATE SCHEMA foo;
    ERROR:  schema "foo" already exists
    postgres=# CREATE SCHEMA IF NOT EXISTS foo;
    NOTICE:  schema "foo" already exists, skipping
    CREATE SCHEMA

Note that subsequent schema elements cannot be used with this option.

    postgres=# CREATE SCHEMA IF NOT EXISTS foo CREATE TABLE aa (a int);
    ERROR:  CREATE SCHEMA IF NOT EXISTS cannot include schema elements
    LINE 1: CREATE SCHEMA IF NOT EXISTS foo CREATE TABLE aa (a int);

The second addition, ALTER TYPE ADD VALUE [IF NOT EXISTS] is useful in the case of enumeration types to condition the addition of new values.

    postgres=# CREATE TYPE character_type AS ENUM ('warrior', 'priest', 'sorcerer');
    CREATE TYPE
    postgres=# ALTER TYPE character_type ADD VALUE IF NOT EXISTS 'magician';
    ALTER TYPE
    postgres=# ALTER TYPE character_type ADD VALUE IF NOT EXISTS 'magician';
    NOTICE:  enum label "magician" already exists, skipping
    ALTER TYPE

The last improvement is also a nice thing to have. Here is what you could obtain prior to 9.3 when trying to use DROP TABLE IF EXISTS on a table using a schema that did not exist.

    postgres=# DROP TABLE IF EXISTS foosch.foo;
    ERROR:  schema "foosch" does not exist

And here is what you get now:

    postgres=# DROP TABLE IF EXISTS foosch.foo;
    NOTICE:  table "foo" does not exist, skipping
    DROP TABLE

Those are definitely nice additions, especially the new extension of IF NOT EXISTS on schemas which was really missing in the existing set.
