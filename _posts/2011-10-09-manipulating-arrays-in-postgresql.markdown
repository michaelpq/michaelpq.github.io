---
author: Michael Paquier
comments: true
date: 2011-10-09 02:54:29+00:00
layout: post
slug: manipulating-arrays-in-postgresql
title: Manipulating arrays in PostgreSQL
wordpress_id: 559
categories:
- PostgreSQL-2
tags:
- array
- data
- database
- element
- manipulation
- postgres
- postgresql
- unnest
---

Arrays can be created easily in PostgreSQL using the additional syntax [] when defining a column of a table.

    CREATE TABLE aa (a int primary key, b int[]);
    CREATE TABLE bb (a int primary key, b varchar(5)[]);

Arrays follow some special grammar. You can insert array data directly with '\{data1,data2\}' format or by using things like ARRAY[data1,data2].

    postgres=# INSERT INTO aa VALUES (1, '\{1,2,3,4\}');
    INSERT 0 1
    postgres=# INSERT INTO aa VALUES (2, ARRAY[1,2,3,4]);
    INSERT 0 1
    postgres=# select * from aa;
     a |     b     
    ---+-----------
     1 | \{1,2,3,4\}
     2 | \{1,2,3,4\}
    (2 rows)

An array in postgres does not have any dimension restrictions. You can create arrays with multiple dimensions if desired.

    postgres=# INSERT INTO aa VALUES (3, '\{\{1,2\},\{3,4\}\}');
    INSERT 0 1
    postgres=# INSERT INTO aa VALUES (4, ARRAY[ARRAY[1,2],ARRAY[3,4]]);
    INSERT 0 1
    postgres=# select * from aa;
     a |       b       
    ---+---------------
     1 | \{1,2,3,4\}
     2 | \{1,2,3,4\}
     3 | \{\{1,2\},\{3,4\}\}
     4 | \{\{1,2\},\{3,4\}\}
    (4 rows)

A special function called array_dims allows to get dimensions of an array.

    postgres=# select a, array_dims(b) from aa;
     a | array_dims 
    ---+------------
     1 | [1:4]
     2 | [1:4]
     3 | [1:2][1:2]
     4 | [1:2][1:2]
    (4 rows)

An array length can be obtained by array_length.

    postgres=# select array_length(b,1) from aa where a = 1;
     array_length 
    --------------
                5
    (1 row)

There are another couple of useful functions like:

  * array_append, array_prepend, to add values directly to an array	
  * array_cat, to assemble arrays

Here is an example.

    postgres=# update aa set b = array_append(b, 5) where a = 1;
    UPDATE 1
    postgres=# select * from aa where a = 1;
     a |      b      
    ---+-------------
     1 | \{1,2,3,4,5\}
    (1 row)

The contribution module int_array contains additional functions on integer arrays to sort elements.

The last function that looks useful for array manipulation are unnest and array_string. array_string returns data of a array as a string (Oh!) with a given separator.

    postgres=# select array_to_string(b,';') from aa where a = 1;
     array_to_string 
    -----------------
     1;2;3;4;5
    (1 row)

This is particularly useful for array manipulation on application side.

unnest decomposes array into single elements. This can be used to refer to foreign tables in IN clauses for example.

    postgres=# select unnest(b) from aa where a = 1;
     unnest 
    --------
          1
          2
          3
          4
          5
    (5 rows)
    postgres=# create table cc (a int, b char(2));
    CREATE TABLE
    postgres=# insert into cc values (1, 'Aa'), (2, 'Bb'), (3, 'Cc'), (4, 'Dd'), (6, 'Ff');
    INSERT 0 5
    postgres=# select b from cc where a in (select unnest(b) from aa where a = 1);
     b  
    ----
     Aa
     Bb
     Cc
     Dd
    (4 rows)

unnest is implemented internally since postgres 8.4. If you use an older version, you can defined it with that.

    CREATE OR REPLACE FUNCTION unnest(anyarray)
      RETURNS SETOF anyelement AS
    $BODY$
    SELECT $1[i] FROM
        generate_series(array_lower($1,1),
                        array_upper($1,1)) i;
    $BODY$
      LANGUAGE 'sql' IMMUTABLE;

Hope you enjoyed this post.
