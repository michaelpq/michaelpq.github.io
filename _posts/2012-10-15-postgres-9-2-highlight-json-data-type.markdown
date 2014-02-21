---
author: Michael Paquier
comments: true
lastmod: 2012-10-15
date: 2012-10-15 02:45:28+00:00
layout: post
type: post
slug: postgres-9-2-highlight-json-data-type
title: 'Postgres 9.2 highlight: JSON data type'
categories:
- PostgreSQL-2
tags:
- '9.2'
- array
- data
- database
- free
- hstore
- json
- native
- open source
- postgres
- postgresql
- row
- type
---

PostgreSQL 9.2 has introduced a new feature related to JSON with a built-in data type. So you can now store inside your database directly JSON fields without the need of an external format checker as it is now directly inside Postgres core. The feature has been added by this commit.

    commit 5384a73f98d9829725186a7b65bf4f8adb3cfaf1
    Author: Robert Haas <rhaas@postgresql.org>
    Date:   Tue Jan 31 11:48:23 2012 -0500

    Built-in JSON data type.

    Like the XML data type, we simply store JSON data as text, after checking
    that it is valid.  More complex operations such as canonicalization and
    comparison may come later, but this is enough for now.

    There are a few open issues here, such as whether we should attempt to
    detect UTF-8 surrogate pairs represented as \uXXXX\uYYYY, but this gets
    the basic framework in place.

A couple of system functions have also been added later to output some row or array data directly as json.

    commit 39909d1d39ae57c3a655fc7010e394e26b90fec9
    Author: Andrew Dunstan <andrew@dunslane.net>
    Date:   Fri Feb 3 12:11:16 2012 -0500

    Add array_to_json and row_to_json functions.

    Also move the escape_json function from explain.c to json.c where it
    seems to belong.

    Andrew Dunstan, Reviewed by Abhijit Menon-Sen.

What actually Postgres core does with JSON fields is to store them as text fields (so maximum size of 1GB) and top of that a string format check can be performed directly in core. Let's use that in a practical use case, a table storing a list of shop items for an RPG game. In an RPG game, there are several types of items, each of them having different fields for its statistics. For example a sword will have an attack value, and a shield a defense value, the opposite being unlogical (except if the sword has a magical defense bonus and the shield some fire protection for example...). Well, what I meant is that you do not need to create multiple tables for each item type but you can possibly store this data in a unique item table thanks to the flexibility of JSON. With the format check done now in Postgres core, you do not need either to perform the string format check on application side.

    postgres=# CREATE TABLE rpg_items (c1 serial, data json);
    CREATE TABLE
    postgres=# INSERT INTO rpg_items (data) VALUES
    postgres-# ('{"name":"sword","buy":"500","sell":"200","description":"basic sword","attack":"10"}');
    INSERT 0 1
    postgres=# INSERT INTO rpg_items (data) VALUES 
    postgres-# ('{"name":"shield","buy":"200","sell":"80","description":"basic shield","defense":"7"}');
    INSERT 0 1
    postgres=# SELECT * FROM rpg_items;
     c1 |                                         data                                         
    ----+--------------------------------------------------------------------------------------
      1 | {"name":"sword","buy":"500","sell":"200","description":"basic sword","attack":"10"}
      2 | {"name":"shield","buy":"200","sell":"80","description":"basic shield","defense":"7"}
    (2 rows)

In case of a format error you will obtain something similar to this:

    postgres=# INSERT INTO rpg_items (data) VALUES ('{"name":"dummy","buy":"200","ppo"}');
    ERROR:  invalid input syntax for type json
    LINE 1: INSERT INTO rpg_items (data) VALUES ('{"name":"dummy","buy":...

Then, you can also manipulate existing tables and output its data to client as JSON.

    postgres=# CREATE TABLE rpg_items_defense (c1 serial, buy int, sell int, description text, defense int);
    CREATE TABLE
    postgres=# INSERT INTO rpg_items_defense (buy, sell,description, defense)
    postgres-# VALUES (200, 80, 'basic shield', 7);
    INSERT 0 1
    postgres=# SELECT row_to_json(row(buy,sell,description,defense)) FROM rpg_items_defense;
                      row_to_json                  
    -----------------------------------------------
     {"f1":200,"f2":80,"f3":"basic shield","f4":7}
    (1 row)

The field names have default values generated automatically by Postgres.

Or output array values as JSON.

    postgres=# CREATE TABLE rpg_items_attack(int serial, fields int[], description text);
    CREATE TABLE
    postgres=# INSERT INTO rpg_items_attack (fields, description) VALUES
    postgres-# ('{500,200,10}','basic sword');
    INSERT 0 1
    postgres=# SELECT row_to_json(row(array_to_json(fields), description)) FROM rpg_items_attack;
                  row_to_json               
    ----------------------------------------
     {"f1":[500,200,10],"f2":"basic sword"}
    (1 row)

This is of course not the only solution possible. Take care of making the good choice when designing your application.
