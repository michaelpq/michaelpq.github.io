---
author: Michael Paquier
comments: true
lastmod: 2013-10-23
date: 2013-10-23 02:09:09+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-improvement-of-column-management-for-auto-updatable-views
title: 'Postgres 9.4 feature highlight: Improvement of column management for auto-updatable views'
wordpress_id: 2006
categories:
- PostgreSQL-2
tags:
- 9.4
- automatic
- column
- data
- database
- development
- granularity
- level
- object
- open source
- postgres
- postgresql
- relation
- table
- tuple
- updatable
- view
---
Auto-updatable views have a new feature in Postgres 9.4 thanks to a patch allowing only a portion of columns to be updatable. Here is the commit introducing the feature:

    commit cab5dc5daf2f6f5da0ce79deb399633b4bb443b5
    Author: Robert Haas
    Date: Fri Oct 18 10:35:36 2013 -0400
 
    Allow only some columns of a view to be auto-updateable.
 
    Previously, unless all columns were auto-updateable, we wouldn't
    inserts, updates, or deletes, or at least not without a rule or trigger;
    now, we'll allow inserts and updates that target only the auto-updateable
    columns, and deletes even if there are no auto-updateable columns at
    all provided the view definition is otherwise suitable.
 
    Dean Rasheed, reviewed by Marko Tiikkaja

In 9.3 where auto-updatable views were introduced, all the columns of the view had to refer directly the relation they are based on to be updatable. Any condition like the use of an aggregate in the SELECT clause would automatically mark all the columns as non-updatable. In this case a dedicated trigger or rules was necessary to kick a DML operation (INSERT, UPDATE or DELETE) to the relation on which the view is based on.

So let's have a look at what this feature improves with the following tables.

    =# CREATE TABLE aa (a int, b int);
    CREATE TABLE
    =# CREATE TABLE bb (a int);
    CREATE TABLE

The SELECT list of the query view can now contain both updatable and non-updatable columns, an updatable column being one referencing directly the underlying relation. In all the other cases, the column is defined as read-only. For example, here is a view mixing both updatable and non-updatable columns in 9.4:

    =# CREATE VIEW aav AS SELECT aa.*, (SELECT avg(a) FROM bb) FROM aa;
    CREATE VIEW

With a 9.3 server, it is simply not possible to perform a DML on this view and it returned an error as below:

    =# INSERT INTO aav(a) VALUES (1);
    ERROR: 55000: cannot insert into view "aav"
    DETAIL: Views that return columns that are not columns of their base relation are not automatically updatable.
    HINT: To enable inserting into the view, provide an INSTEAD OF INSERT trigger or an unconditional ON INSERT DO INSTEAD rule.
    LOCATION: rewriteTargetView, rewriteHandler.c:2321
    =# SELECT column_name, is_updatable FROM information_schema.columns WHERE table_name = 'aav';
     column_name | is_updatable
    -------------+--------------
               a | NO
               b | NO
             avg | NO
   (3 rows)

All the columns are marked as non-updatable.

Now here is what happens for a 9.4 server... As you can see only the two columns referring to the parent relation 'aa' are writable.

    =# INSERT INTO aav(a) VALUES (1);
    INSERT 0 1
    =# SELECT * FROM aa;
     a | b
    ---+---
     1 |
    (1 row)
    =# SELECT column_name, is_updatable FROM information_schema.columns WHERE table_name = 'aav';
     column_name | is_updatable
    -------------+--------------
               a | YES
               b | YES
             avg | NO
    (3 rows)

Note also that if the view contains in its outmost SELECT list references to multiple relations, all the columns cannot be updatable.

    =# CREATE VIEW aav2 AS SELECT aa.a AS a1, aa.b, bb.a AS a2 FROM aa, bb where aa.a = bb.a;
    CREATE VIEW
    =# SELECT column_name, is_updatable FROM information_schema.columns WHERE table_name = 'aav2';
     column_name | is_updatable
    -------------+--------------
              a1 | NO
               b | NO
              a2 | NO
    (3 rows)

This feature is really going to facilitate more the life of application developers by reducing the number of rules and triggers that were needed on views having a single parent relation.
