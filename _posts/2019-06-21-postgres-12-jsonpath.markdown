---
author: Michael Paquier
lastmod: 2019-06-21
date: 2019-06-21 03:58:34+00:00
layout: post
type: post
slug: postgres-12-jsonpath
title: 'Postgres 12 highlight - SQL/JSON path'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 12
- json
- jsonb

---

Postgres ships in-core data types for JSON with specific functions and operators
(json since 9.2, and jsonb which is a binary representation since 9.4).  The
upcoming Postgres 12 is becoming more compliant with the SQL specifications by
introducing SQL/JSON path language, introduced mainly by the following commit:

    commit: 72b6460336e86ad5cafd3426af6013c7d8457367
    author: Alexander Korotkov <akorotkov@postgresql.org>
    date: Sat, 16 Mar 2019 12:15:37 +0300

    Partial implementation of SQL/JSON path language

    SQL 2016 standards among other things contains set of SQL/JSON features for
    JSON processing inside of relational database.  The core of SQL/JSON is JSON
    path language, allowing access parts of JSON documents and make computations
    over them.  This commit implements partial support JSON path language as
    separate datatype called "jsonpath".  The implementation is partial because
    it's lacking datetime support and suppression of numeric errors.  Missing
    features will be added later by separate commits.

    Support of SQL/JSON features requires implementation of separate nodes, and it
    will be considered in subsequent patches.  This commit includes following
    set of plain functions, allowing to execute jsonpath over jsonb values:

    * jsonb_path_exists(jsonb, jsonpath[, jsonb, bool]),
    * jsonb_path_match(jsonb, jsonpath[, jsonb, bool]),
    * jsonb_path_query(jsonb, jsonpath[, jsonb, bool]),
    * jsonb_path_query_array(jsonb, jsonpath[, jsonb, bool]).
    * jsonb_path_query_first(jsonb, jsonpath[, jsonb, bool]).

    This commit also implements "jsonb @? jsonpath" and "jsonb @@ jsonpath", which
    are wrappers over jsonpath_exists(jsonb, jsonpath) and jsonpath_predicate(jsonb,
    jsonpath) correspondingly.  These operators will have an index support
    (implemented in subsequent patches).

    Catversion bumped, to add new functions and operators.

    Code was written by Nikita Glukhov and Teodor Sigaev, revised by me.
    Documentation was written by Oleg Bartunov and Liudmila Mantrova.  The work
    was inspired by Oleg Bartunov.

    Discussion: https://postgr.es/m/fcc6fc6a-b497-f39a-923d-aa34d0c588e8%402ndQuadrant.com
    Author: Nikita Glukhov, Teodor Sigaev, Alexander Korotkov, Oleg Bartunov, Liudmila Mantrova
    Reviewed-by: Tomas Vondra, Andrew Dunstan, Pavel Stehule, Alexander Korotkov

The documentation can be looked at in details for all the additions, but
here is a short description of each concept introduced.  Note that there
are many operators and features part of what has been committed, so only
a very small part is presented here.

First, one needs to know about some
[expressions](https://www.postgresql.org/docs/devel/functions-json.html#FUNCTIONS-SQLJSON-PATH),
which are similar to XPath for XML data to do lookups and searches into
different parts of a JSON object.  Let's take a sample of data, so here
is a JSON blob representing a character in an RPG game (this should be
normalized, but who cares here):

    =# CREATE TABLE characters (data jsonb);
    CREATE TABLE
    =# INSERT INTO characters VALUES ('
    { "name" : "Iksdargotso",
      "id" : 1,
      "sex" : "male",
      "hp" : 300,
      "level" : 10,
      "class" : "warrior",
      "equipment" :
       {
         "rings" : [
           { "name" : "ring of despair",
             "weight" : 0.1
           },
           {"name" : "ring of strength",
            "weight" : 2.4
           }
         ],
         "arm_right" : "Sword of flame",
         "arm_left" : "Shield of faith"
       }
    }');

The basic grammar of those expressions is to use the keys part of the JSON
objects combined with some elements:

  * Dots to move into a tree
  * Brackets for access to a given array member coupled with a position.
  * Variables, with '$' representing a JSON text and '@' for result path
  evaluations.
  * Context variables, which are basically references with '$' and a
  variable name, with values that can be passed down to dedicated functions.

So for example, when applied to the previous JSON data sample we can
reach the following parts of the tree with these expressions:

  * $.level refers to 10.
  * $.equipment.arm\_left refers to "Shield of faith".
  * $.equipment.rings refers to the full array of rings.
  * $.equipment.rings[0] refers to the first ring listed in the previous
  array (contrary to arrays members are zero-based).

Then comes the second part.  These expressions are implemented using a
new datatype called
[jsonpath](https://www.postgresql.org/docs/devel/datatype-json.html#DATATYPE-JSONPATH),
which is a binary representation of the parsed SQL/JSON path.  This data
type has its own parsing rules defined as of
src/backend/utils/adt/jsonpath\_gram.y parsing the data into a tree of
several JsonPathParseItem items.  After knowing about that comes the
actual fun.  Because, combining a jsonpath, a jsonb blob and the new set
of functions implemented, it is possible to do some actual lookups in the
JSON blob.  jsonb\_path\_query() is likely the most interesting one, as it
allows to directly query a portion of the JSON blob:

    =# SELECT jsonb_path_query(data, '$.name') FROM characters;
         name
    ---------------
     "Iksdargotso"
    (1 row)
    =#  SELECT jsonb_path_query(data, '$.equipment.rings[0].name')
          AS ring_name
        FROM characters;
         ring_name
    -------------------
     "ring of despair"
    (1 row)

Note as well that there is some wildcard support, for example with an
asterisk which returns all the elements of a set:

    =#  SELECT jsonb_path_query(data, '$.equipment.rings[0].*') AS data
        FROM characters;
          name
    -------------------
     "ring of despair"
     0.1
    (2 rows)

New operators are also available and these allow for much more complex
operations.  One possibility is that it is possible to apply some functions
within a result set as part of the expression.  Here is for example how
to apply floor() for a integer conversion for the weight of all the rings:

    =# SELECT jsonb_path_query(data, '$.equipment.rings[*].weight.floor()')
         AS weight
       FROM characters;
     weight
    --------
     0
     2
    (2 rows)

This is actually only the top of cake, because one can do much more
advanced context-related lookups for a JSON blob.  For example you
can apply a filter on top of it and fetch only a portion of them.
Here is for example a way to get the names of all rings for a character
which are heavier than 1kg (I am afraid that the unit is true as this
applies to a ring of strength after all):

    =# SELECT jsonb_path_query(data, '$.equipment.rings[*] ? (@.weight > 1)')->'name'
         AS name
       FROM characters;
           name
    --------------------
     "ring of strength"
    (1 row)

Note that all the most basic comparison operators are implemented and
listed in [the documentation](https://www.postgresql.org/docs/devel/functions-json.html#FUNCTIONS-SQLJSON-FILTER-EX-TABLE),
so there is a lot of fun ahead.  Due to time constraints, not all the
features listed in the specification have been implemented as datetime
is for example lacking, still this is a nice first cut.

Note: there is a kind of mathematical easter egg in this post.  Can
you find it?
