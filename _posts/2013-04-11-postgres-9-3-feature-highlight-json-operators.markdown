---
author: Michael Paquier
comments: true
lastmod: 2013-04-11
date: 2013-04-11 05:52:51+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-json-operators
title: 'Postgres 9.3 feature highlight: JSON operators'
categories:
- PostgreSQL-2
tags:
- '9.3'
- API
- data
- database
- feature
- function
- json
- manipulation
- open source
- operator
- postgres
- postgresql
- process
- read
- write
---

Postgres 9.3 is going to be a great release for JSON data type. After having a look at the [new functions for data generation](http://michael.otacoo.com/postgresql-2/postgres-9-3-feature-highlight-json-data-generation/), let's look at the new JSON features that the commit below brings.

    commit a570c98d7fa0841f17bbf51d62d02d9e493c7fcc
    Author: Andrew Dunstan <andrew@dunslane.net>
    Date:   Fri Mar 29 14:12:13 2013 -0400
    
    Add new JSON processing functions and parser API.
    
    The JSON parser is converted into a recursive descent parser, and
    exposed for use by other modules such as extensions. The API provides
    hooks for all the significant parser event such as the beginning and end
    of objects and arrays, and providing functions to handle these hooks
    allows for fairly simple construction of a wide variety of JSON
    processing functions. A set of new basic processing functions and
    operators is also added, which use this API, including operations to
    extract array elements, object fields, get the length of arrays and the
    set of keys of a field, deconstruct an object into a set of key/value
    pairs, and create records from JSON objects and arrays of objects.
    
    Catalog version bumped.
    
    Andrew Dunstan, with some documentation assistance from Merlin Moncure.

Based on stored JSON data, this commit introduces a new layer of APIs, operators and functions that can be used to manipulate and process JSON data. There are 4 new operators and 8 new functions (hopefully I counted right), so as there is a lot of content this post is only focused on the new operators.

The following set of data is used for all the examples presented in this post with some subsets of data, arrays and plain variables.

    postgres=# CREATE TABLE aa (a int, b json);
    CREATE TABLE
    postgres=# INSERT INTO aa VALUES (1, '{"f1":1,"f2":true,"f3":"Hi I''m \"Daisy\""}');
    INSERT 0 1
    postgres=# INSERT INTO aa VALUES (2, '{"f1":{"f11":11,"f12":12},"f2":2}');
    INSERT 0 1
    postgres=# INSERT INTO aa VALUES (3, '{"f1":[1,"Robert \"M\"",true],"f2":[2,"Kevin \"K\"",false]}');
    INSERT 0 1

The first operator is "->", that can be used to fetch field values directly from JSON data. It can be used with a text value identifying the key of field.

    postgres=# SELECT b->'f1' AS f1, b->'f3' AS f3 FROM aa WHERE a = 1;
     f1 |         f3         
    ----+--------------------
     1  | "Hi I'm \"Daisy\""
    (1 row)

Multiple keys can also be used in chain to retrieve data or another JSON subset of data.

    postgres=# SELECT b->'f1'->'f12' AS f12 FROM aa WHERE a = 2;
     f12 
    -----
      12
    (1 row)
    postgres=# SELECT b->'f1' AS f1 FROM aa WHERE a = 2;
             f1          
    ---------------------
     {"f11":11,"f12":12}
    (1 row)

In a more interesting way, when an integer is used as key, you can fetch data directly in a stored array, like that for example:

    postgres=# SELECT b->'f1'->0 as f1_0 FROM aa WHERE a = 3;
     f1_0 
    ------
      1
    (1 row)

The second operator added is "->>". Contrary to "->" that returns a JSON legal text, "->>" returns plain text.

    postgres=# SELECT b->>'f3' AS f1 FROM aa WHERE a = 1;
           f1       
    ----------------
     Hi I'm "Daisy"
    (1 row)
    postgres=# SELECT b->'f3' AS f1 FROM aa WHERE a = 1;
             f1         
    --------------------
     "Hi I'm \"Daisy\""
    (1 row)

Similarly to "->", it is possible to use either an integer or a text as key. For an integer, the key represents the position of element in an array.

    postgres=# SELECT b->'f1'->>1 as f1_0 FROM aa WHERE a = 3;
        f1_0    
    ------------
     Robert "M"
    (1 row)
    postgres=# SELECT b->'f1'->1 as f1_0 FROM aa WHERE a = 3;
          f1_0      
    ----------------
     "Robert \"M\""
    (1 row)

Of course, you cannot fetch data from an array using a field name.

    postgres=#  SELECT b->'f1'->>'1' as f1_0 FROM aa WHERE a = 3;
    ERROR:  cannot extract field from a non-object

As well as you cannot fetch a field using an element number.

    postgres=#  SELECT b->1 as f1_0 FROM aa WHERE a = 3;
    ERROR:  cannot extract array element from a non-array

The last 2 operators added are "#>" and "#>>". With those ones, it is possible to fetch directly an element in an array without using a combo of the type "column->'$FIELD'->$INT\_INDEX. This can make your queries far more readable when manipulating arrays in JSON.

    postgres=# SELECT b#>'{f1,1}' as f1_0 FROM aa WHERE a = 3;
          f1_0      
    ----------------
     "Robert \"M\""
    (1 row)
    postgres=# SELECT b#>>'{f1,1}' as f1_0 FROM aa WHERE a = 3;
        f1_0    
    ------------
     Robert "M"
    (1 row)

"#>" fetches text data in a legal JSON format, and "#>>" fetches data as plain text.

In short, those operators are good meat for brain, and nice additions for many applications.
