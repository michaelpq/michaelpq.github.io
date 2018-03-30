---
author: Michael Paquier
lastmod: 2014-06-22
date: 2014-06-22 15:04:23+00:00
layout: post
type: post
slug: manipulating-jsonb-data-with-key-unique
title: 'Manipulating jsonb data by abusing of key uniqueness'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.4
- json
- index

---
The [jsonb datatype]
(http://www.postgresql.org/docs/devel/static/datatype-json.html) newly
introduced in Postgres 9.4 has a property that makes its manipulation
rather facilitate when doing operations on it with embedded functions:
it does not allow duplicated object keys. On the contrary, json allows
that as you can see here:

    =# SELECT '{"key1":"val1", "key2":"val2", "key1":"val1bis"}'::json;
                           json                       
    --------------------------------------------------
     {"key1":"val1", "key2":"val2", "key1":"val1bis"}
    (1 row)
    =# SELECT '{"key1":"val1", "key2":"val2", "key1":"val1bis"}'::jsonb;
                    jsonb                
    -------------------------------------
     {"key1": "val1bis", "key2": "val2"}
    (1 row)

jsonb\_each and jsonb\_each_text are functions that can decompose the
outmost json object as a table with two columns: keys and values. Using
it with multiple set of jsonb values and UNION queries, this can be used
to create a unique table containing multiple sets of jsonb data (works
with json as well).

    =# SELECT * FROM jsonb_each_text('{"key11":"val11", "key12":"val12"}'::jsonb)
           UNION
       SELECT * FROM jsonb_each_text('{"key21":"val21", "key22":"val22"}'::jsonb);
      key  | value 
    -------+-------
     key12 | val12
     key11 | val11
     key21 | val21
     key22 | val22
    (4 rows)

Finally, it is possible to use json\_object\_agg to rebuild a new json
field based on such key/value pairs shaped as a table:

    =# WITH json_union AS
        (SELECT *
           FROM jsonb_each_text('{"key11":"val11", "key12":"val12"}'::jsonb)
         UNION
         SELECT *
           FROM jsonb_each_text('{"key21":"val21", "key22":"val22"}'::jsonb))
       SELECT json_object_agg(key, value) FROM json_union;
                                    json_object_agg                                 
    --------------------------------------------------------------------------------
     { "key12" : "val12", "key11" : "val11", "key21" : "val21", "key22" : "val22" }
    (1 row)

The return type of json_object_agg is json, so if you have duplicate
keys in the jsonb fields merged with UNION, you need an implicit cast
to elimitate the duplicates. Note in the following example that the
key "key11" is duplicated with values "val11" in the first jsonb field,
and "val11bis" in the second.

    =# WITH json_union AS (
         SELECT *
           FROM jsonb_each_text('{"key11":"val11", "key12":"val12"}'::jsonb)
         UNION ALL
         SELECT *
           FROM jsonb_each_text('{"key21":"val21", "key22":"val22", "key11":"val11bis"}'::jsonb))
       SELECT json_object_agg(key, value)::jsonb FROM json_union;
                                    json_object_agg                               
    -----------------------------------------------------------------------------
     {"key11": "val11bis", "key12": "val12", "key21": "val21", "key22": "val22"}
    (1 row)

"val11bis" is the value assigned to key "key11" after the cast to jsonb.

Using this simple query let's now create a simple SQL function able to append
a jsonb value with another jsonb value. Note if keys are duplicated, priority
is given to the second field:

    =# CREATE FUNCTION jsonb_append(jsonb, jsonb)
       RETURNS jsonb AS $$
         WITH json_union AS
           (SELECT * FROM jsonb_each_text($1)
              UNION ALL
            SELECT * FROM jsonb_each_text($2))
         SELECT json_object_agg(key, value)::jsonb FROM json_union;
       $$ LANGUAGE SQL;
    =# SELECT jsonb_append('{"a1":"v1", "a2":"v2"}', '{"a1":"b1", "a3":"v3"}');
                 jsonb_merge              
    --------------------------------------
     {"a1": "b1", "a2": "v2", "a3": "v3"}
    (1 row)

Doing a little bit more, we can create a wrapper on top of jsonb\_append that
simply simply appends a key and a value. The key/value pair can be built with
json\_build\_object for example.

    =# CREATE FUNCTION jsonb_add_key_value_single(jsonb, text, text)
       RETURNS jsonb as $$
         SELECT jsonb_append($1, json_build_object($2, $3)::jsonb);
       $$ LANGUAGE SQL;
    =# SELECT jsonb_add_key_value_single('{"a1":"v1", "a2":"v2"}', 'a1', 'v3');
     jsonb_add_key_value_single 
    ----------------------------
     {"a1": "v3", "a2": "v2"}
    (1 row)

Here is a version a bit more complex, able to pass multiple key/value pairs
using a VARIADIC SQL function using json_object to build each field:

    =# CREATE FUNCTION jsonb_append_key_value_pairs(jsonb, variadic text[])
       RETURNS jsonb AS $$
         SELECT jsonb_append($1, json_object($2)::jsonb);
       $$ LANGUAGE SQL;
    =# SELECT jsonb_append_key_value_pairs('{"a1":"v1", "a2":"v2"}', 'a3', 'v3', 'a1', 'v4');
         jsonb_append_key_value_pairs     
    --------------------------------------
     {"a1": "v4", "a2": "v2", "a3": "v3"}
    (1 row)

Note that in both cases the value of key "a1" has been updated to a new
value. This set of functions can be useful to update jsonb fields directly
with UPDATE queries for example.

    =# CREATE TABLE jsonb_tab (data jsonb);
    CREATE TABLE
    =# INSERT INTO jsonb_tab VALUES ('{"a1":"v1", "a2":"v2", "a3":"v3"}');
    INSERT 0 1
    =# UPDATE jsonb_tab SET data = jsonb_append_key_value_pairs(data, 'a1', 'toto1', 'a3', 'toto2');
    UPDATE 1
    =# SELECT data FROM jsonb_tab;
                        data                    
    --------------------------------------------
     {"a1": "toto1", "a2": "v2", "a3": "toto2"}
    (1 row)

Be careful that even if this updates only one field, the whole jsonb value
is updated at once, so this lacks performance on large values, but it has
the advantage of facilitating a lot operations with Postgres 9.4 and jsonb
by abusing of the limitation related to duplicated keys.
