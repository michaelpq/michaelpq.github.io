---
author: Michael Paquier
lastmod: 2023-05-07
date: 2023-05-07 07:52:22+00:00
layout: post
type: post
slug: 2023-05-07-postgres-16-json-predicate
title: 'Postgres 16 highlight - JSON predicates'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 16
- json
- jsonb

---

PostgreSQL 16 includes a set of features related to JSON to make the engine
more compliant with the SQL standard.  One of these features has been
introduced by the following
[commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=6ee3020):

    commit: 6ee30209a6f161d0a267a33f090c70c579c87c00
    author: Alvaro Herrera <alvherre@alvh.no-ip.org>
    date: Fri, 31 Mar 2023 22:34:04 +0200
    SQL/JSON: support the IS JSON predicate

    This patch introduces the SQL standard IS JSON predicate. It operates
    on text and bytea values representing JSON, as well as on the json and
    jsonb types. Each test has IS and IS NOT variants and supports a WITH
    UNIQUE KEYS flag. The tests are:

    IS JSON [VALUE]
    IS JSON ARRAY
    IS JSON OBJECT
    IS JSON SCALAR

    These should be self-explanatory.

    The WITH UNIQUE KEYS flag makes these return false when duplicate keys
    exist in any object within the value, not necessarily directly contained
    in the outermost object.

As the commit itself tells, these keywords explain what they are able to do:
they allow one to check if a given JSON object is considered valid or not,
depending on the keywords available:

  * ARRAY works for all valid arrays, like [1,2,"true",false], or even
  [{"a":1},1,true] (surprise!).
  * OBJECT is for JSON values parsed with curly brackets, like {"a":1}.
  * SCALAR works for all the single values, like "null", integers, strings or
  booleans.
  * The default VALUE, as an optional keyword, can be used to check if a
  value can be parsed as JSON, be it a single value, an array, a JSON object,
  or even empty objects like '[]' or '{}', but not NULL.  The previous checks
  are restrictions of this one depending on the object type.

The regression tests that have been added in the commit mentioned above
include a full summary of the values worth checking, and here is a minimalist
version of that:

    =# SELECT vals,
        vals IS JSON AS is_json,
        vals IS JSON SCALAR AS is_scalar,
        vals IS JSON OBJECT AS is_object,
        vals IS JSON ARRAY AS is_array
      FROM (VALUES
             (NULL::json),  -- Note that NULL is always NULL.
             ('"null"'::json),
             ('123'),
             ('{"a":1, "b":2}'),
             ('[1, 2, 3, {"a":1}]'),
             ('{"a":1, "b":[1, 2, 3]}')
           ) AS tab(vals);
              vals          | is_json | is_scalar | is_object | is_array 
    ------------------------+---------+-----------+-----------+----------
     null                   | null    | null      | null      | null
     "null"                 | t       | t         | f         | f
     123                    | t       | t         | f         | f
     {"a":1, "b":2}         | t       | f         | t         | f
     [1, 2, 3, {"a":1}]     | t       | f         | f         | t
     {"a":1, "b":[1, 2, 3]} | t       | f         | t         | f
    (6 rows)

One last thing is the clause { WITH | WITHOUT } UNIQUE KEYS, that validates
an object if it has unique keys.  First, WITHOUT works the same as the default
when this clause is *not* specified, meaning that WITHOUT UNIQUE KEYS would not
check if the input value have duplicated keys.  WITH UNIQUE KEYS just adds on
top of the original format and type checks a lookup of the keys.  Put it
simply, if there are duplicate keys, the object is considered as invalid.
Taking the previous example, here are some values with such checks:

    =# SELECT vals,
        vals IS JSON OBJECT WITH UNIQUE KEYS AS obj_with,
        vals IS JSON OBJECT WITHOUT UNIQUE KEYS AS obj_without,
        vals IS JSON ARRAY WITH UNIQUE KEYS AS array_with,
        vals IS JSON ARRAY WITHOUT UNIQUE KEYS AS array_without
      FROM (VALUES
             ('{"a":1, "b":2}'), -- JSON object with different keys.
             ('{"a":1, "a":2}'), -- JSON object with same keys.
             ('{"a":1, "b":{"c":2, "d":3}}'), -- Nested object with different keys
             ('{"a":1, "b":{"c":2, "c":3}}'), -- Nested object with same keys
             ('[{"a":1}, {"b":2}]'), -- Elements and different keys.
             ('[{"a":1}, {"a":2}]'), -- Elements and same keys.
             ('[{"a":1}, {"b":2, "c":3}]'), -- Different keys everywhere
             ('[{"a":1}, {"a":2, "b":3}]'), -- Same keys across elements.
             ('[{"a":1}, {"b":2, "b":3}]') -- Same key in single element.
           ) AS tab(vals);
                vals             | obj_with | obj_without | array_with | array_without 
    -----------------------------+----------+-------------+------------+---------------
     {"a":1, "b":2}              | t        | t           | f          | f
     {"a":1, "a":2}              | f        | t           | f          | f
     {"a":1, "b":{"c":2, "d":3}} | t        | t           | f          | f
     {"a":1, "b":{"c":2, "c":3}} | f        | t           | f          | f
     [{"a":1}, {"b":2}]          | f        | f           | t          | t
     [{"a":1}, {"a":2}]          | f        | f           | t          | t
     [{"a":1}, {"b":2, "c":3}]   | f        | f           | t          | t
     [{"a":1}, {"a":2, "b":3}]   | f        | f           | t          | t
     [{"a":1}, {"b":2, "b":3}]   | f        | f           | f          | t
    (9 rows)

The previous table may be a bit confusing to parse, so here are the important
points about the fields that are invalid under WITH UNIQUE KEYS:

  * {"a":1, "a":2}, the second value.  This is a simple object with duplicated
  keys, nothing amazing here..
  * {"a":1, "b":{"c":2, "c":3}}, the fourth value, has a nested JSON object
  that uses the same keys, making the whole invalid.
  * [{"a":1}, {"b":2, "b":3}], the last value, is invalid, as it uses an element
  with the same keys.

Following the same reasoning, an array element that has a nested JSON object
with duplicated keys is considered incorrect under WITH UNIQUE KEYS, see this
example:

    =# SELECT '[{"a":1}, {"b":2, "c":{"d":3, "d":4}}]'
         IS JSON ARRAY WITH UNIQUE KEYS;
     ?column? 
    ----------
     f
    (1 row)
