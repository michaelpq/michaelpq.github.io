---
author: Michael Paquier
comments: true
lastmod: 2013-04-03
date: 2013-04-03 14:29:21+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-json-data-generation
title: 'Postgres 9.3 feature highlight: JSON data generation'
categories:
- PostgreSQL-2
tags:
- '9.3'
- data
- database
- enhancement
- feature
- function
- improvement
- json
- leverage
- light
- open source
- operation
- operator
- postgres
- postgresql
- server
- site
- store
- type
- value
- web
- website
---

Postgres 9.2 has introduced [JSON as a server data type](http://michael.otacoo.com/postgresql-2/postgres-9-2-highlight-json-data-type/). At this point, the data was simply stored on server side with integrated wrappers checking that data had a correct JSON format. It was a good first step in order to store directly JSON data on server side but core features in 9.2 have its limitations in terms of JSON data manipulation and transformation.

Two new sets of JSON features have been added to PostgreSQL 9.3 planned to be released this year: functions related to data generation and a new set of APIs for data processing. The one this post deals with the ability to generate JSON data based on existing data types. The second set of features (operators and new processing functions) will be explained in a future post.

So... Functions for JSON data generation have been added by this commit.

    commit 38fb4d978c5bfc377ef979e2595e3472744a3b05
    Author: Andrew Dunstan <andrew@dunslane.net>
    Date:   Sun Mar 10 17:35:36 2013 -0400
    
    JSON generation improvements.
    
    This adds the following:
    
        json_agg(anyrecord) -> json
        to_json(any) -> json
        hstore_to_json(hstore) -> json (also used as a cast)
        hstore_to_json_loose(hstore) -> json
    
    The last provides heuristic treatment of numbers and booleans.
    
    Also, in json generation, if any non-builtin type has a cast to json,
    that function is used instead of the type's output function.
    
    Andrew Dunstan, reviewed by Steve Singer.
    Catalog version bumped.

The first function called to_json permits to return a given value as valid JSON.

    postgres=# create table aa (a bool, b text);
    CREATE TABLE
    postgres=# INSERT INTO aa VALUES (true, 'Hello "Darling"');
    INSERT 0 1
    postgres=# INSERT INTO aa VALUES (false, NULL);
    INSERT 0 1
    postgres=# SELECT to_json(a) AS bool_json, to_json(b) AS txt_json FROM aa;
     bool_json |      txt_json       
    -----------+---------------------
     true      | "Hello \"Darling\""
     false     | 
    (2 rows)

Boolean values are returned as plain true/false, texts are quoted as valid JSON fields.

json\_agg is a function that can transform a record into a JSON array.

    postgres=# SELECT json_agg(aa) FROM aa;
                   json_agg                
    ---------------------------------------
     [{"a":true,"b":"Hello \"Darling\""}, +
      {"a":false,"b":null}]
    (1 row)

The other tools for data generation are included in the contrib module hstore. Do you remember? This module can be used to store [key/value pairs in a single table column](http://michael.otacoo.com/postgresql-2/postgres-feature-highlight-hstore/). It is now possible to cast hstore data as json with some native casting or with function hstore\_to\_json.

    postgres=# CREATE TABLE aa (id int, txt hstore);
    CREATE TABLE
    postgres=# INSERT INTO aa VALUES (1, 'f1=>t, f2=>2, f3=>"Hi", f4=>NULL');
    INSERT 0 1
    postgres=# SELECT id, txt::json, hstore_to_json(txt) FROM aa;
     id |                      txt                       |                 hstore_to_json                 
    ----+------------------------------------------------+------------------------------------------------
      1 | {"f1": "t", "f2": "2", "f3": "Hi", "f4": null} | {"f1": "t", "f2": "2", "f3": "Hi", "f4": null}
    (1 row)

Note that in this case boolean and numerical values are treated as plain text when casted.

hstore\_to\_json\_loose can enforce the conversion of boolean and numerical values to a better format, like that:

    postgres=# SELECT id, hstore_to_json_loose(txt) FROM aa;
     id |             hstore_to_json_loose              
    ----+-----------------------------------------------
      1 | {"f1": true, "f2": 2, "f3": "Hi", "f4": null}
    (1 row)

And now boolean and integer values inserted previously have a better look, no?

Having such tools natively in Postgres core server is really a nice addition for data manipulation and transformation of values into legal JSON.
However, you need to know that this set of tools is only the top of the iceberg for the JSON features added in 9.3... There are also [new operators and APIs](http://www.postgresql.org/docs/devel/static/functions-json.html), which will be covered in more details with examples in one of my next posts. So... TBC.
