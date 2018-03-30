---
author: Michael Paquier
lastmod: 2014-03-05
date: 2014-03-05 14:37:27+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-copy-force-null
title: 'Postgres 9.4 feature highlight - COPY FORCE NULL'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.4
- copy
- force
- null

---

When using [COPY](http://www.postgresql.org/docs/devel/static/sql-copy.html),
there is an option called FORCE_NOT_NULL allowing to enforce a string to be
not null even if it is not quoted. Here is an example of how it works:

    =# CREATE TABLE aa (a text);
    CREATE TABLE
    =# \COPY aa FROM STDIN WITH (FORMAT csv, FORCE_NOT_NULL(a));
    Enter data to be copied followed by a newline.
    End with a backslash and a period on a line by itself.
    >> ""
    >> 
    >> \.
    =# \pset null 'null'
    Null display (null) is "null".
    =# SELECT * FROM aa;
     a 
    ---
     
     
    (2 rows)

In this case, even if the values are empty, FORCE_NOT_NULL forces them to
be inserted as empty strings and not NULL values. Now, let's look at the
new option FORCE_NULL that is introduced in Postgres 9.4 by this commit,
feature actually written by [Ian](http://sql-info.de), hacker living in
Japan as well as the author of this blog.

    commit 3b5e03dca2afea7a2c12dbc8605175d0568b5555
    Author: Andrew Dunstan <andrew@dunslane.net>
    Date:   Tue Mar 4 17:31:59 2014 -0500

    Provide a FORCE NULL option to COPY in CSV mode.

    This forces an input field containing the quoted null string to be
    returned as a NULL. Without this option, only unquoted null strings
    behave this way. This helps where some CSV producers insist on quoting
    every field, whether or not it is needed. The option takes a list of
    fields, and only applies to those columns. There is an equivalent
    column-level option added to file_fdw.

    Ian Barwick, with some tweaking by Andrew Dunstan, reviewed by Payal
    Singh.

Contrary to FORCE_NOT_NULL, this can be used to force an empty value to
be inserted as NULL even if it is quoted.

    =# TRUNCATE aa;
    TRUNCATE TABLE
    =# \COPY aa FROM STDIN WITH (FORMAT csv, FORCE_NULL(a));
    Enter data to be copied followed by a newline.
    End with a backslash and a period on a line by itself.
    >> ""
    >> 
    >> \.
    =# SELECT * FROM aa;
      a   
    ------
     null
     null
    (2 rows)

[file\_fdw](http://www.postgresql.org/docs/devel/static/file-fdw.html) comes
up as well with a similar new option, and it can be used on columns.

    =# CREATE EXTENSION file_fdw;
    CREATE EXTENSION
    =# CREATE SERVER file_server FOREIGN DATA WRAPPER file_fdw;
    CREATE SERVER
    =# CREATE FOREIGN TABLE test (
        a int,
        b text OPTIONS (force_null 'true'),
        c text OPTIONS (force_not_null 'true')
    ) SERVER file_server
    OPTIONS ( filename '/path/to/data/test.csv', format 'csv');
    CREATE FOREIGN TABLE
    =# \! cat /path/to/data/test.csv
    1,"",
    2,,""
    =# SELECT * FROM test;
     a |  b   | c 
    ---+------+---
     1 | null | 
     2 | null | 
    (2 rows)

Note that both force_null and force_not_null cannot be specified on the same
column.

    =# ALTER FOREIGN TABLE test ALTER COLUMN b
       OPTIONS (force_not_null 'true');
    ERROR:  42601: conflicting or redundant options
    HINT:  option "force_not_null" cannot be used together with "force_null"
    LOCATION:  file_fdw_validator, file_fdw.c:274

And that's all for this short but instructive post, for a feature proved
to be useful for Or**le to Postgres migrations.
