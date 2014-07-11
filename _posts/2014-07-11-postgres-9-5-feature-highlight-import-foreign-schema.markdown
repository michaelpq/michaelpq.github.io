---
author: Michael Paquier
comments: true
lastmod: 2014-07-11
date: 2014-07-11 13:47:43+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-import-foreign-schema
title: 'Postgres 9.5 feature highlight: IMPORT FOREIGN SCHEMA'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- 9.5
- new
- feature
- foreign
- table
- import
- spec
- wrapper
- fdw
- schema
---
[IMPORT FOREIGN SCHEMA]
(http://www.postgresql.org/docs/devel/static/sql-importforeignschema.html)
is a SQL query defined in the SQL specification allowing to import from
a foreign source a schema made of foreign tables. Its support has been
added in Postgres 9.5 with the following commit:

    commit 59efda3e50ca4de6a9d5aa4491464e22b6329b1e
    Author: Tom Lane <tgl@sss.pgh.pa.us>
    Date:   Thu Jul 10 15:01:31 2014 -0400

    Implement IMPORT FOREIGN SCHEMA.

    This command provides an automated way to create foreign table definitions
    that match remote tables, thereby reducing tedium and chances for error.
    In this patch, we provide the necessary core-server infrastructure and
    implement the feature fully in the postgres_fdw foreign-data wrapper.
    Other wrappers will throw a "feature not supported" error until/unless
    they are updated.

    Ronan Dunklau and Michael Paquier, additional work by me

This feature is made of two parts:

  * New API available for foreign data wrappers to support this SQL query
  * Support for this query in postgres\_fdw, foreign-data wrapper (FDW) for
PostgreSQL available in core.

The new API available has the following shape:

    List *
    ImportForeignSchema (ImportForeignSchemaStmt *stmt, Oid serverOid);

ImportForeignSchemaStmt is a parsed representation of the raw query of
IMPORT FOREIGN SCHEMA and serverOid is the OID of the FDW server used for
the import. The parsed statement contains all the information needed by
a FDW to fetch all the information to rebuild a schema fetched from a
remote source, mainly being:

  * Type of import done with stmt->list\_type with the table list (not for
ALL)
   * FDW\_IMPORT\_SCHEMA\_LIMIT\_TO (LIMIT clause specified in query) for
a restricted list of table names imported
   * FDW\_IMPORT\_SCHEMA\_EXCEPT (EXCEPT clause specified in query) for a
list of tables to not fetch during import
   * FDW\_IMPORT\_SCHEMA\_ALL (no LIMIT TO or EXCEPT clauses in query) to let
the FDW know that all the tables from the foreign schema
  * Remote schema name
  * List of options to customize the import

Then this API needs to return a list of raw queries that will be applied
as-is by the server after parsing them. The local schema is overridden by
server to avoid any abuse. Documentation should be used as a reference for
[more details]
(http://www.postgresql.org/docs/devel/static/fdw-callbacks.html#FDW-CALLBACKS-IMPORT)
as well.

The second part of the feature is the support of IMPORT FOREIGN SCHEMA for
postgres\_fdw itself, allowing to import a schema from a different node. For
example let's take the case of two instances on the same server. The first
node listens to port 5432 and uses postgres\_fdw to connect to a second node
listening to port 5433 (for more details on how to set of that refer to
[that](/postgresql-2/postgres-9-3-feature-highlight-postgres_fdw/) or
directly have look at the [official documentation]
(http://www.postgresql.org/docs/devel/static/postgres-fdw.html)).

On the remote node (listening to 5433) the two following tables are created
on a default schema, aka "public":

    =# CREATE TABLE remote_tab1 (a int not null);
    CREATE TABLE
    =# CREATE TABLE remote_tab2 (b timestamp default now());
    CREATE TABLE

Importing them locally on schema public is a matter of running this command
on the local node (local schema name is defined with clause INTO, and foreign
schema at the beginning of the query):

    =# IMPORT FOREIGN SCHEMA public FROM SERVER postgres_server INTO public;
    IMPORT FOREIGN SCHEMA
    =# \d
                    List of relations
     Schema |    Name     |     Type      | Owner  
    --------+-------------+---------------+--------
     public | remote_tab1 | foreign table | ioltas
     public | remote_tab2 | foreign table | ioltas
    (2 rows)

IMPORT FOREIGN SCHEMA offers some control to the list of tables imported with
LIMIT TO and EXCEPT, so this query would only import the table remote\_tab1
in schema test\_import1:

    =# CREATE SCHEMA test_import1;
    CREATE SCHEMA
    =# IMPORT FOREIGN SCHEMA public LIMIT TO (remote_tab1)
       FROM SERVER postgres_server INTO test_import1;
    IMPORT FOREIGN SCHEMA
    =# \d test_import1.*
          Foreign table "test_import1.remote_tab1"
      Column |  Type   | Modifiers |    FDW Options    
     --------+---------+-----------+-------------------
      a      | integer | not null  | (column_name 'a')
     Server: postgres_server
     FDW Options: (schema_name 'public', table_name 'remote_tab1')

And this query would import everything except remote\_tab1 in schema
test\_import2:

     =# CREATE SCHEMA test_import2;
     CREATE SCHEMA
     =# IMPORT FOREIGN SCHEMA public EXCEPT (remote_tab1)
        FROM SERVER postgres_server INTO test_import2;
     IMPORT FOREIGN SCHEMA
     =# \d test_import2.*
                    Foreign table "test_import2.remote_tab2"
      Column |            Type             | Modifiers |    FDW Options    
     --------+-----------------------------+-----------+-------------------
      b      | timestamp without time zone |           | (column_name 'b')
    Server: postgres_server
    FDW Options: (schema_name 'public', table_name 'remote_tab2')

By default, the import will try to import collations and NOT NULL constraints.
So, coming back to what has been imported on schema public, relation remote\_tab1
is defined like that, with a NOT NULL constaint:

    =# \d remote_tab1
             Foreign table "public.remote_tab1"
      Column |  Type   | Modifiers |    FDW Options    
     --------+---------+-----------+-------------------
      a      | integer | not null  | (column_name 'a')
     Server: postgres_server
     FDW Options: (schema_name 'public', table_name 'remote_tab1')

Note that this can be controlled with the clause OPTIONS in IMPORT FOREIGN
SCHEMA, postgres_fdw offerring 3 options:

  * import_collate to import collates, default is true
  * import_default to import default expressions, default is false
  * import_not_null to import NOT NULL constaints, default is true

import_default is the tricky part, particularly for volatile expressions.
Import will also fail if the default expression is based on objects not
created locally, like what would happen when trying to import a relation
with a SERIAL column.
