---
author: Michael Paquier
lastmod: 2015-06-28
date: 2015-06-28 13:53:44+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-new-jsonb-functions
title: 'Postgres 9.5 feature highlight: New JSONB functions and operators'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- highlight
- feature
- 9.5
- json
- jsonb
- function
- element
- delete
- pretty
- field
- key
- value
- indexing
- operator
- concatenate

---

jsonb is coming up with a set of new features in Postgres 9.5. Most of them
have been introduced by the following commit:

    commit: c6947010ceb42143d9f047c65c1eac2b38928ab7
    author: Andrew Dunstan <andrew@dunslane.net>
    date: Tue, 12 May 2015 15:52:45 -0400
    Additional functions and operators for jsonb

    jsonb_pretty(jsonb) produces nicely indented json output.
    jsonb || jsonb concatenates two jsonb values.
    jsonb - text removes a key and its associated value from the json
    jsonb - int removes the designated array element
    jsonb - text[] removes a key and associated value or array element at
    the designated path
    jsonb_replace(jsonb,text[],jsonb) replaces the array element designated
    by the path or the value associated with the key designated by the path
    with the given value.

    Original work by Dmitry Dolgov, adapted and reworked for PostgreSQL core
    by Andrew Dunstan, reviewed and tidied up by Petr Jelinek.

Note that some slight modifications have been done after this commit though.
So the list of new operators and functions presented here is not exactly the
one listed in this commit log but the one that will be included in Postgres
9.5 alpha 1 that will be released next week. Also, something worth mentioning
is that portion of this work is available as the extension jsonbx that is
compatible even with 9.4 installations (see
[here](https://github.com/erthalion/jsonbx)).

So, 4 new operators have been added in the existing jsonb set in 9.5.

**jsonb || jsonb** for concatenation on two jsonb fields, where two things
can be noted. First, key name ordering is done depending on their names (this
is not surprising as on-disk-format is a parsed tree). Then, the last value
of a given key will be used as jsonb enforces key uniqueness, even of course
if values are of json type.

    =# SELECT '{"a1":"v1","a3":"v3"}'::jsonb || '{"a2":"v2"}'::jsonb AS field;
                     field
    --------------------------------------
     {"a1": "v1", "a2": "v2", "a3": "v3"}
    (1 row)
    =# SELECT '{"a1":{"b1":"y1","b2":"y2"},"a2":"v2"}'::jsonb ||
              '{"a1":"v1"}'::jsonb AS field;
              field
    --------------------------
     {"a1": "v1", "a2": "v2"}
    (1 row)

**jsonb - text**, which can be used to remove in a jsonb field a given key
at the top-level of the field (no nested operations possible here).

    =# SELECT '{"a1":"v1","a2":"v2"}'::jsonb - 'a1' AS field;
         field
    --------------
     {"a2": "v2"}
    (1 row)

**jsonb - int**, to remove in a jsonb array field the value matching the given
position, negative values counting from the end of the array, and 0 as the first
element. If the position matches no existing value, the array remains the same.

    =# SELECT '["a", "b"]'::jsonb - 0 AS pos_0,
        '["a", "b"]'::jsonb - 1 AS pos_1,
        '["a", "b"]'::jsonb - 2 AS pos_2,
        '["a", "b"]'::jsonb - -1 AS pos_less_1;
     pos_0 | pos_1 |   pos_2    | pos_less_1
    -------+-------+------------+------------
     ["b"] | ["a"] | ["a", "b"] | ["a"]
    (1 row)

**jsonb #- text\[\]** (operator has been renamed for clarity after more
discussion) to remove a key in the given nested path. An integer can as
well be used to remove an element in an array at the wanted position.
Here is for example how this works with a mix of nested arrays and json
values:

    =# SELECT '{"a1":{"b1":"y1","b2":["c1", {"c2":"z1","c3":"z3"}]},"a2":"v2"}'::jsonb #- '{a1}' AS level_1;
        level_1
    --------------
     {"a2": "v2"}
    (1 row)
    =# SELECT '{"a1":{"b1":"y1","b2":["c1", {"c2":"z1","c3":"z3"}]},"a2":"v2"}'::jsonb #- '{a1,b2}' AS level_2;
                  level_2
    ----------------------------------
     {"a1": {"b1": "y1"}, "a2": "v2"}
    (1 row)
    =# SELECT '{"a1":{"b1":"y1","b2":["c1", {"c2":"z1","c3":"z3"}]},"a2":"v2"}'::jsonb #- '{a1,b2,1}' AS level_3;
                         level_3
    ------------------------------------------------
     {"a1": {"b1": "y1", "b2": ["c1"]}, "a2": "v2"}
    (1 row)
    =# SELECT '{"a1":{"b1":"y1","b2":["c1", {"c2":"z1","c3":"z3"}]},"a2":"v2"}'::jsonb #- '{a1,b2,1,c3}' AS level_4;
                                level_4
    --------------------------------------------------------------
     {"a1": {"b1": "y1", "b2": ["c1", {"c2": "z1"}]}, "a2": "v2"}
    (1 row)

Then there are three new functions.

**jsonb\_pretty()**, to format a jsonb value with a nice json indentation. This
will be useful for many applications aiming at having nice-looking data output.

    =# SELECT jsonb_pretty('{"a1":{"b1":"y1","b2":["c1", {"c2":"z1","c3":"z3"}]},"a2":"v2"}'::jsonb);
            jsonb_pretty
    -----------------------------
     {                          +
         "a1": {                +
             "b1": "y1",        +
             "b2": [            +
                 "c1",          +
                 {              +
                     "c2": "z1",+
                     "c3": "z3" +
                 }              +
             ]                  +
         },                     +
         "a2": "v2"             +
     }
    (1 row)

**jsonb\_set()** to update a value for a given key. This function has support
for nested keys as well as a path to redirect to a nested key can be specified,
even within an array. The second argument of the function defines the path
where the key is located, and the third argument assigns the new value. A
fourth argument can be specified as well to enforce the creation of a new
key/value pair if the key does not exist in the specified path. Default is
true.

    -- Here the value in path a1->b2 gets updated.
    =# SELECT jsonb_set('{"a1":{"b1":"y1","b2":"y2"},"a2":"v2"}'::jsonb,
                        '{a1,b2}', '"z2"');
                      jsonb_set
    ----------------------------------------------
     {"a1": {"b1": "y1", "b2": "z2"}, "a2": "v2"}
    (1 row)
    -- Here a new key is added in a1 as b3 does not exist.
    =# SELECT jsonb_set('{"a1":{"b1":"y1","b2":"y2"},"a2":"v2"}'::jsonb,
                        '{a1,b3}', '"z3"', true);
                            jsonb_set
    ----------------------------------------------------------
     {"a1": {"b1": "y1", "b2": "y2", "b3": "z3"}, "a2": "v2"}
    (1 row)
    -- Key does not exist in path a1, do not create it then.
    =# SELECT jsonb_set('{"a1":{"b1":"y1","b2":"y2"},"a2":"v2"}'::jsonb,
                        '{a1,b3}', '"z3"', false);
                      jsonb_set
    ----------------------------------------------
     {"a1": {"b1": "y1", "b2": "y2"}, "a2": "v2"}
    (1 row)

Finally there is **jsonb\_strip\_nulls()** (available as well for json data
type with json\_strip\_nulls) to remove key/value pairs with NULL values. This
function does through all the parsed tree levels, and does not affect NULL
values in arrays.

    =# SELECT json_strip_nulls('{"a1":{"b1":"y1","b2":null},"a2":null}');
      json_strip_nulls
    --------------------
     {"a1":{"b1":"y1"}}
    (1 row)
    =# SELECT json_strip_nulls('{"a1":[1,null,"a"],"a2":null}');
      json_strip_nulls
    ---------------------
     {"a1":[1,null,"a"]}
    (1 row)

Each one of those functions is going to alleviate the amount of code
that applications had to create previously with some equivalent in either
plpgsql/sql on backend side, or even things on frontend side (think
jsonb\_pretty for user-facing applications for example), so that's
definitely useful. Note that Postgres 9.5 alpha 1 will be released
next week. So if you have remarks or complaints about its features
(not limited to this ticket), don't hesitate to contact community about
that. And be sure to test this new stuff, again and again.
