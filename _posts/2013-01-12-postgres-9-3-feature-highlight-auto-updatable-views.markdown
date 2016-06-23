---
author: Michael Paquier
lastmod: 2013-01-12
date: 2013-01-12 06:29:55+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-auto-updatable-views
title: 'Postgres 9.3 feature highlight - auto-updatable views'
categories:
- PostgreSQL-2
tags:
- '9.3'
- automatic
- database
- delete
- dml
- easy
- insert
- open source
- option
- postgres
- postgresql
- rules
- trigger
- updatable
- view
---

Prior to PostgreSQL 9.3, trying to execute a DML on a view results in an error. The view is not able to execute directly a query to its parent table.
For example, you can see this kind of behavior in 9.2.

    postgres=# CREATE TABLE aa (a int, b int);
    CREATE TABLE
    postgres=# CREATE VIEW aav AS SELECT * FROM aa;
    CREATE VIEW
    postgres=# INSERT INTO aav VALUES (1,2);
    ERROR:  cannot insert into view "aav"
    HINT:  You need an unconditional ON INSERT DO INSTEAD rule or an INSTEAD OF INSERT trigger.

Solving that is a matter of using triggers or rules on this view to redirect the given query (INSERT, UPDATE or DELETE) to the wanted parent relation. Here for example by using an INSTEAD rule.

    postgres=# CREATE RULE aav_insert AS ON INSERT TO aav 
    postgres-# DO INSTEAD INSERT INTO aa VALUES (NEW.a, NEW.b);
    CREATE RULE
    postgres=# INSERT INTO aav VALUES (1,2);
    INSERT 0 1
    postgres=# select * from aa;
     a | b 
    ---+---
     1 | 2
    (1 row)
    postgres=# DROP rule aav_insert ON aav;
    DROP RULE

Or with an INSTEAD trigger (trigger on views have been introduced in 9.1).

    postgres=# CREATE FUNCTION aav_insert() RETURNS TRIGGER AS $$
    DECLARE
      query   varchar;
    BEGIN
      -- Execute action only for an INSERT                                                            
      IF TG_OP = 'INSERT' then
        query := 'INSERT INTO aa VALUES(' || NEW.a || ', ' || NEW.b || ');';
        EXECUTE query;
      END IF;
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    postgres=# CREATE TRIGGER aav_insert_tr INSTEAD OF INSERT ON aav
    postgres=# FOR EACH ROW EXECUTE PROCEDURE aav_insert();
    postgres=# INSERT INTO aav VALUES (7,99);
    INSERT 0 0
    postgres=# select * from aav;
     a | b  
    ---+----
     1 |  2
     7 | 99
    (2 rows)

PostgreSQL 9.3 introduces a new functionality that allows application programmers not to care anymore about using rules or triggers when executing INSERT, UPDATE or DELETE on views. This feature has been introduced by this commit and is called auto-updatable views.

    commit a99c42f291421572aef2b0a9360294c7d89b8bc7
    Author: Tom Lane <tgl@sss.pgh.pa.us>
    Date:   Sat Dec 8 18:25:48 2012 -0500

    Support automatically-updatable views.

    This patch makes "simple" views automatically updatable, without the need
    to create either INSTEAD OF triggers or INSTEAD rules.  "Simple" views
    are those classified as updatable according to SQL-92 rules.  The rewriter
    transforms INSERT/UPDATE/DELETE commands on such views directly into an
    equivalent command on the underlying table, which will generally have
    noticeably better performance than is possible with either triggers or
    user-written rules.  A view that has INSTEAD OF triggers or INSTEAD rules
    continues to operate the same as before.

    For the moment, security_barrier views are not considered simple.
    Also, we do not support WITH CHECK OPTION.  These features may be
    added in future.

    Dean Rasheed, reviewed by Amit Kapila

This feature presents the advantage to facilitate the maintenance work of the rules and triggers that the application has to write prior to 9.3 in order to run an INSERT/UPDATE/DELETE query directly on a view.

There are multiple cases where views containing cannot be auto-updatable, a couple of examples being views containing clauses like GROUP BY, LIMIT, OFFSET, DISTINCT or HAVING. There are other restrictions so be sure to refer to the documentation for that.

Now let's have a look at this feature.

    postgres=# CREATE TABLE aa (a int, b int);
    CREATE TABLE
    postgres=# CREATE VIEW aav1 AS SELECT * FROM aa;
    CREATE VIEW

Two new system functions called pg\_view\_is\_insertable and pg\_view\_is\_updatable have been introduced to check if a view can receive an INSERT or UPDATE directly.

    postgres=# select pg_view_is_updatable('aav1'::regclass),
    postgres-# pg_view_is_insertable('aav1'::regclass);
     pg_view_is_updatable | pg_view_is_insertable 
    ----------------------+-----------------------
     t                    | t
    (1 row)

So it looks to be the case for the view aav1, then let's try it.

    postgres=# INSERT INTO aav1 VALUES (1,2);
    INSERT 0 1
    postgres=# SELECT * FROM aa;
     a | b 
    ---+---
     1 | 2
    (1 row)
    postgres=# UPDATE aav1 SET b = 50 WHERE a = 1;
    UPDATE 1
    postgres=# SELECT * FROM aa;
     a | b  
    ---+----
     1 | 50
    (1 row)
    postgres=# DELETE FROM aav1 WHERE a = 1;
    DELETE 1
    postgres=# SELECT * FROM aa;
     a | b 
    ---+---
    (0 rows)

INSERT, UPDATE and DELETE queries have been executed without the need of additional triggers or rules. Yeah.

One last thing, it is possible to check if a view is auto-updatable by looking at its information in information\_schema.tables. Let's add here also the example of a view that cannot be auto-updatable.

    postgres=# CREATE VIEW aav2 AS SELECT count(*) FROM aa;
    CREATE VIEW
    postgres=# SELECT table_name, is_insertable_into 
    postgres-# FROM information_schema.tables
    postgres-# WHERE table_name LIKE 'aav%';
     table_name | is_insertable_into 
    ------------+--------------------
     aav1       | YES
     aav2       | NO
   (2 rows)

And I think that's all about auto-updatable views.
Enjoy!
