---
author: Michael Paquier
lastmod: 2014-03-28
date: 2014-03-28 7:21:08+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-trigger-foreign-tables
title: 'Postgres 9.4 feature highlight: Triggers on foreign tables'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.4
- open source
- database
- foreign
- data
- wrapper
- table
- data
- trigger
- insert
- instead
- before
- after
- view
---
PostgreSQL 9.4 is coming with more support for triggers, making them now
firable on foreign tables. This feature has been introduced by the following
commit:

    commit 7cbe57c34dec4860243e6d0f81738cfbb6e5d069
    Author: Noah Misch <noah@leadboat.com>
    Date:   Sun Mar 23 02:16:34 2014 -0400

    Offer triggers on foreign tables.

    This covers all the SQL-standard trigger types supported for regular
    tables; it does not cover constraint triggers.  The approach for
    acquiring the old row mirrors that for view INSTEAD OF triggers.  For
    AFTER ROW triggers, we spool the foreign tuples to a tuplestore.

    This changes the FDW API contract; when deciding which columns to
    populate in the slot returned from data modification callbacks, writable
    FDWs will need to check for AFTER ROW triggers in addition to checking
    for a RETURNING clause.

    In support of the feature addition, refactor the TriggerFlags bits and
    the assembly of old tuples in ModifyTable.

    Ronan Dunklau, reviewed by KaiGai Kohei; some additional hacking by me.

Note that TRUNCATE and INSTEAD OF are not supported. Such restrictions make
sense thinking that in the former case foreign tables do not have physical
data in the server so it is hard to delete the data files associated to
a relation that the server has no control on. In the latter case, INSTEAD
OF triggers are limited to views and local server is not sure in which state
is the data of remote server (a foreign table might be a view on remote
side though).

Now let's have a look at that using postgres_fdw that ships the necessary
facility for the support of triggers. The example used here is a PostgreSQL
server that connects to itself but on a different database called "foreign\_db"
for the remote source (feel free to have a look at some other examples
to set up postgres\_fdw like [this one]
(/postgresql-2/postgres-9-3-feature-highlight-postgres_fdw/)):

    =# CREATE EXTENSION postgres_fdw;
    CREATE EXTENSION
    =# CREATE SERVER postgres_server
       FOREIGN DATA WRAPPER postgres_fdw
       OPTIONS (host 'localhost', dbname 'foreign_db');
    CREATE SERVER
    =# CREATE USER MAPPING FOR PUBLIC SERVER
    postgres_server OPTIONS (password '');
    CREATE USER MAPPING
    =# CREATE FOREIGN TABLE aa_foreign (a int, b text)
       SERVER postgres_server OPTIONS (table_name 'aa');
    =# \c foreign_db
    You are now connected to database "foreign_db" as user "michael".
    =# CREATE TABLE aa (a int PRIMARY KEY, b text);
    CREATE TABLE
    =# INSERT INTO aa VALUES (1, 'aa'), (2, 'bb');
    INSERT 0 2

Everything is in place, it is time to move on with the new features
involving triggers. Here is for example the case of a trigger that
tracks DML activity on the foreign table with an audit table located
locally using [json data type]
(http://www.postgresql.org/docs/devel/static/datatype-json.html) and
row\_to\_json():

    =# CREATE TABLE audit_foreign (relid oid,
        op_type text,
        old_data json,
        new_data json);
    CREATE TABLE
    =# CREATE FUNCTION audit_trigger()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'INSERT' THEN
          INSERT INTO audit_foreign(relid, op_type, new_data)
               SELECT TG_RELID, TG_OP, row_to_json(NEW);
          RETURN new;
        ELSIF TG_OP = 'UPDATE' THEN
          INSERT INTO audit_foreign(relid, op_type, old_data, new_data)
               SELECT TG_RELID, TG_OP, row_to_json(OLD), row_to_json(NEW);
          RETURN new;
        ELSE
          -- DELETE case
          INSERT INTO audit_foreign(relid, op_type, old_data)
               SELECT TG_RELID, TG_OP, row_to_json(OLD);
          RETURN old;
        END IF;
      END;
      $$;
    CREATE FUNCTION
    =# CREATE TRIGGER audit_kick
          AFTER INSERT OR UPDATE OR DELETE on aa_foreign
          FOR EACH ROW
          EXECUTE PROCEDURE audit_trigger();
    CREATE TRIGGER
    =# \d aa_foreign 
         Foreign table "public.aa_foreign"
     Column |  Type   | Modifiers | FDW Options 
    --------+---------+-----------+-------------
     a      | integer |           | 
     b      | text    |           | 
    Triggers:
        audit_kick AFTER INSERT OR DELETE OR UPDATE ON aa_foreign FOR EACH \
            ROW EXECUTE PROCEDURE audit_trigger()
    Server: postgres_server
    FDW Options: (table_name 'aa')

This is somewhat classic, each time a DML occurs on the foreign table,
the trigger tracks the activity of each row changed. Now let's try it
with some data and see the audit changes:

    =# INSERT INTO aa_foreign VALUES (3, 'bb');
    INSERT 0 1
    =# UPDATE aa_foreign SET b = 'tu' WHERE a = 1;
    UPDATE 1
    =# DELETE FROM aa_foreign WHERE a = 2;
    DELETE 1
    =# SELECT relid::regclass AS relname,
          op_type,
          old_data,
          new_data
       FROM audit_foreign;
      relname   | op_type |     old_data     |     new_data     
    ------------+---------+------------------+------------------
     aa_foreign | INSERT  | null             | {"a":3,"b":"bb"}
     aa_foreign | UPDATE  | {"a":1,"b":"aa"} | {"a":1,"b":"tu"}
     aa_foreign | DELETE  | {"a":2,"b":"bb"} | null
    (3 rows)

Cool! The foreign table activity is now tracked thanks to the triggers on it.
Note how this takes advantage as well of the json data type (could be [jsonb]
(http://www.postgresql.org/docs/devel/static/datatype-json.html) as well).

A last word: constraint triggers are not supported, (foreign tables cannot
have constraints by the way, they are managed on the remote side).

    =# CREATE CONSTRAINT TRIGGER trig_constraint
         AFTER INSERT ON aa_foreign
         FOR EACH ROW EXECUTE PROCEDURE audit_trigger();
    ERROR:  42809: "aa_foreign" is a foreign table
    DETAIL:  Foreign tables cannot have constraint triggers.
    LOCATION:  CreateTrigger, trigger.c:221

Et voilà!
