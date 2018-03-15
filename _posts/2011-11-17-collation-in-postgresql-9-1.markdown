---
author: Michael Paquier
lastmod: 2011-11-17
date: 2011-11-17 06:44:31+00:00
layout: post
type: post
slug: collation-in-postgresql-9-1
title: Collation in PostgreSQL 9.1
categories:
- PostgreSQL-2
tags:
- 9.1
- character
- collation
- database
- language
- order
- postgres
- postgresql
- utf8
---

Collation is a new functionality of PostgreSQL 9.1 that allows to specify the sort order by table column or for an operation.

In Ubuntu, the collation types supported by your system are listed in /var/lib/locales/supported.d.
In case you installed support for language French, you can have a look at all the languages supported in the file fr.

    $ cat /var/lib/locales/supported.d/fr 
    fr_LU.UTF-8 UTF-8
    fr_CA.UTF-8 UTF-8
    fr_CH.UTF-8 UTF-8
    fr_BE.UTF-8 UTF-8
    fr_FR.UTF-8 UTF-8

So here, this system supports French from Luxembourg, Belgium, France, Canada and Switzerland.

Here is an easy example of a table using collated columns. First a local collation based on French is created. Then table is created and filled with data.

    postgres=# create collation fr_FR (locale = 'fr_FR.utf8');
    CREATE COLLATION
    postgres=# create table test(french_name text collate "fr_FR", eng_name text collate "en_US");
    CREATE TABLE
    postgres=# insert into test values ('la', 'la');
    INSERT 0 1
    postgres=# insert into test values ('le', 'le');
    INSERT 0 1
    postgres=# insert into test values ('li', 'li');
    INSERT 0 1
    postgres=# insert into test values ('lo', 'lo');
    INSERT 0 1
    postgres=# insert into test values ('lu', 'lu');
    INSERT 0 1
    postgres=# \d test
            Table "public.test"
       Column    | Type |   Modifiers   
    -------------+------+---------------
     french_name | text | collate fr_FR
     eng_name    | text | collate en_US

So column 1 is collated in French, column 2 in English.

What happens in the case of a order by?

    postgres=# select * from test order by 1;
     french_name | eng_name 
    -------------+----------
     le          | le
     la          | la
     li          | li
     li          | lu
     lo          | lo
    (5 rows)

In this case the strings are classified in French.

    postgres=# select * from test order by 2;
     french_name | eng_name 
    -------------+----------
     la          | la
     le          | le
     li          | li
     lo          | lo
     lu          | lu
    (5 rows)

Here the American English order is used.

However collation is very useful when doing string comparisons in different languages. Of course you cannot compare columns that have different collations.

    postgres=# select * from test where french_name < eng_name;
    ERROR:  could not determine which collation to use for string comparison
    HINT:  Use the COLLATE clause to set the collation explicitly.

But you can enforce the order by the another collation in a kind of cast style.

    postgres=# select * from test where french_name < (eng_name collate fr_FR);
     french_name | eng_name 
    -------------+----------
     le          | le
     li          | li
     lo          | lo
     lu          | lu
    (4 rows)

You can do a lot of things with such features, just never forget that an ORDER BY always needs a collation or you will get an error.

    postgres=# select * from test order by french_name || eng_name;
    ERROR:  collation mismatch between implicit collations "fr_FR" and "en_US"
    LINE 1: select * from test order by french_name || eng_name;
    postgres=# select * from test order by french_name || eng_name collate fr_FR;
     french_name | eng_name 
    -------------+----------
     le          | le
     la          | la
     li          | li
     lo          | lo
     lu          | lu
    (5 rows)
