---
author: Michael Paquier
comments: true
lastmod: 2013-04-17
date: 2013-04-17 16:30:29+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-json-parsing-functions
title: 'Postgres 9.3 feature highlight: JSON parsing functions'
wordpress_id: 1836
categories:
- PostgreSQL-2
tags:
- '9.3'
- API
- array
- cut
- database
- deparsing
- function
- json
- key
- open source
- parsing
- postgres
- postgresql
- record
- server
- set
- side
- value
---

Continuing on the coverage of new JSON features added in Postgres 9.3, and after writing about [JSON data generation](http://michael.otacoo.com/postgresql-2/postgres-9-3-feature-highlight-json-data-generation/) and [JSON operators](http://michael.otacoo.com/postgresql-2/postgres-9-3-feature-highlight-json-operators/), let's now focus on some new functions that can be used for the parsing of JSON data.

The are many new functions introduced:

  * json\_each, json\_each\_text
  * json\_extract\_path, json\_extract\_path\_text
  * json\_object\_keys
  * json\_populate\_record, json\_populate\_recordset
  * json\_array\_length
  * json\_array\_elements

The following set of data is used in all the examples of this post,.

    postgres=# CREATE TABLE aa (a int, b json);
    CREATE TABLE
    postgres=# INSERT INTO aa VALUES (1, '{"f1":1,"f2":true,"f3":"Hi I''m \"Daisy\""}');
    INSERT 0 1
    postgres=# INSERT INTO aa VALUES (2, '{"f1":2,"f2":false,"f3":"Hi I''m \"Dave\""}');
    INSERT 0 1
    postgres=# INSERT INTO aa VALUES (3, '{"f1":3,"f2":true,"f3":"Hi I''m \"Popo\""}');
    INSERT 0 1
    postgres=# INSERT INTO aa VALUES (4, '{"f1":{"f11":11,"f12":12},"f2":2}');
    INSERT 0 1
    postgres=# INSERT INTO aa VALUES (5, '{"f1":[1,"Robert \"M\""],"f2":[2,"Kevin \"K\"",false]}');
    INSERT 0 1

So now let's begin. The most valuable functions might be json\_each and json\_each\_text which can be used to expand JSON data as key/value records.

    postgres=# SELECT * FROM json_each((SELECT b FROM aa WHERE a = 1));
     key |       value        
    -----+--------------------
     f1  | 1
     f2  | true
     f3  | "Hi I'm \"Daisy\""
    (3 rows)

The difference between json\_each and json\_each\_text is that the former returns values as legal JSON format and the latter returns it as text. 

    postgres=# SELECT * FROM json_each_text((SELECT b FROM aa WHERE a = 1));
     key |     value      
    -----+----------------
     f1  | 1
     f2  | true
     f3  | Hi I'm "Daisy"
    (3 rows)

This operation is effective only on the outermost field.

    postgres=# SELECT * FROM json_each((SELECT b FROM aa WHERE a = 4)) WHERE key = 'f1';
     key |        value        
    -----+---------------------
     f1  | {"f11":11,"f12":12}
    (1 row)

And you can also apply this operation on some inner fields by selecting directly an inner JSON field or using some WITH mechanism.

    =# SELECT * FROM json_each((SELECT b->'f1' FROM aa WHERE a = 4));
     key | value 
    -----+-------
     f11 | 11
     f12 | 12
    (2 rows)

json\_extract\_path and json\_extract\_path\_text can be used to extract a field value based on some given keys, or a chain or keys, equivalent to what the operators "->" and "->>" can respectively do.

    postgres=# SELECT json_extract_path(b, 'f1') AS f1a, b->'f1' AS f1b FROM aa WHERE a = 4;
             f1a         |         f1b         
    ---------------------+---------------------
     {"f11":11,"f12":12} | {"f11":11,"f12":12}
    (1 row)
    postgres=# SELECT json_extract_path(b, 'f1', 'f12') AS f12a, b->'f1'->'f12' AS f12b FROM aa WHERE a = 4;
     f12a | f12b 
    ------+------
     12   | 12
    (1 row)

json\_object\_keys retrieves the set of keys of a given JSON object on the outermost object. As it returns the field names of all the tuples scanned, be sure to group the results or to select a limited number of tuples.

    postgres=# SELECT json_object_keys(b) FROM aa GROUP BY 1 ORDER BY 1;
     json_object_keys 
    ------------------
     f1
     f2
     f3
    (3 rows)
    postgres=# SELECT json_object_keys(b->'f1') FROM aa WHERE a = 4;
     json_object_keys 
    ------------------
     f11
     f12
    (2 rows)

Next, json\_populate\_record can help in casting a JSON record into a given type.

    postgres=# CREATE TYPE aat AS (f1 int, f2 bool, f3 text);
    CREATE TYPE
    postgres=# SELECT * FROM json_populate_record(null::aat, (SELECT b FROM aa WHERE a = 1)) AS popo;
     f1 | f2 |       f3       
    ----+----+----------------
      1 | t  | Hi I'm "Daisy"
    (1 row)

This operation can only be used on a single row.

    postgres=# SELECT * FROM json_populate_record(null::aat, (SELECT b FROM aa WHERE a = 1 OR a = 2)) AS popo;
    ERROR:  more than one row returned by a subquery used as an expression

Similarly to json\_populate\_record, json\_populate\_recordset can be used on a set of records. It can become particularly powerful when combined with json\_agg.

    postgres=# SELECT * FROM json_populate_recordset(null::aat, (SELECT json_agg(b) FROM aa WHERE a < 4)) AS popo;
     f1 | f2 |       f3       
    ----+----+----------------
      1 | t  | Hi I'm "Daisy"
      2 | f  | Hi I'm "Dave"
      3 | t  | Hi I'm "Popo"
    (3 rows)

Note that this operation does not work on nested objects, aka when the JSON fields are not strictly the same for each row.

    postgres=# SELECT * FROM json_populate_recordset(null::aat, (SELECT json_agg(b) FROM aa WHERE a = 1 OR a = 4), false) AS popo;
    ERROR:  cannot call json_populate_recordset on a nested object

Finally there are two functions focused on the manipulation and analysis of JSON arrays. The first function is called json\_array\_length. With this you can get the number of elements in a JSON array.

    SELECT json_array_length(b->'f1') FROM aa WHERE a = 5;
     json_array_length 
    -------------------
                     2
    (1 row)
    postgres=# SELECT json_array_length(b->'f2') FROM aa WHERE a = 5;
     json_array_length 
    -------------------
                     3
    (1 row)

If used on an object that is not an array, this function complains with a nice error message.

    postgres=# SELECT json_array_length(b->'f1') FROM aa WHERE a = 1;
    ERROR:  cannot get array length of a scalar
    postgres=# SELECT json_array_length(b->'f1') FROM aa WHERE a = 4;
    ERROR:  cannot get array length of a non-array

The second one is json\_array\_elements which expends a JSON array to a set of elements.

    postgres=# SELECT json_array_elements(b->'f1') FROM aa WHERE a = 5;
     json_array_elements 
    ---------------------
      1
     "Robert \"M\""
    (2 rows)
    postgres=# SELECT json_array_elements(b->'f1') FROM aa WHERE a = 1;
    ERROR:  cannot call json_array_elements on a scalar
    postgres=# SELECT json_array_elements(b->'f1') FROM aa WHERE a = 4;
    ERROR:  cannot call json_array_elements on a non-array

Combined with the new JSON features for data generation and operators, parsing functions complete the new set of tools implemented in Postgres 9.3 here to leverage the manipulation of JSON data directly on server side. The addition of such features continues the morphing of PostgreSQL from a database software to a database platform, JSON features making it stepping more in the field of NoSQL and document-oriented systems. So now, if you want to create an application which is JSON-oriented, simply use Postgres!
