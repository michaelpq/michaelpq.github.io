---
author: Michael Paquier
lastmod: 2012-10-22
date: 2012-10-22 03:03:32+00:00
layout: post
type: post
slug: postgres-feature-highlight-hstore
title: 'Postgres feature highlight - hstore'
categories:
- PostgreSQL-2
tags:
- 9.2
- hstore
- postgres
- postgresql

---

[hstore](http://www.postgresql.org/docs/9.2/static/hstore.html) is a PostgreSQL contrib module in core code for a pretty long time. Its code is located in contrib/hstore in source folder. It is particularly useful to store sets of key/value in a single table column.

Since Postgres 9.1, its installation needs to be done in two phases.
First install the hstore library, here done from the source code. Please note that your postgres package normally already contains it.
So after downloading the source code and installing the core, do the following commands.

    cd $PG_SOURCE_ROOT
    cd contrib/hstore
    make install

At this point all the libraries and files related to hstore are installaed in $INSTALL\_FOLDER/share/extension.

    $ ls $INSTALL_FOLDER/share/extension
    hstore--1.0--1.1.sql  hstore--1.1.sql  hstore--unpackaged--1.0.sql  hstore.control

Then connect to your Postgres server and finish hstore installation with CREATE EXTENSION command.

    postgres=# CREATE EXTENSION hstore;
    CREATE EXTENSION
    postgres=# \dx hstore
                             List of installed extensions
       Name  | Version | Schema |                   Description                    
    --------+---------+--------+--------------------------------------------------
     hstore | 1.1     | public | data type for storing sets of (key, value) pairs
    (1 row)

With a psql client, '\dx' allows to check the list of extensions already installed on your server.

A new column type called hstore has been added. This is the column used to store the list of key/value pairs for the table.
Let's take a table referencing a list of products as an example.

    postgres=# create table products (id serial, characs hstore);
    CREATE TABLE

The insertion of data can be done with several methods. Here are some of them.

    postgres=# -- common insertion
    postgres=# INSERT INTO products(characs) VALUES ('author=>Dave, date=>"Dec 2012", price=>"500", currency=>"dollar"');
    INSERT 0 1
    postgres=# -- array-based insertion
    postgres=# INSERT INTO products (characs) VALUES (hstore(array['author','date','stock'],array['Mike','Nov 2012','200']));
    INSERT 0 1
    postgres=# -- single-pair insertion
    postgres=# INSERT INTO products (characs) VALUES (hstore('author','Kim')); -- single-element
    INSERT 0 1
    postgres=# SELECT * FROM products;
     id |                                  characs                                   
    ----+----------------------------------------------------------------------------
      1 | "date"=>"Dec 2012", "price"=>"500", "author"=>"Dave", "currency"=>"dollar"
      2 | "date"=>"Nov 2012", "stock"=>"200", "author"=>"Mike"
      3 | "author"=>"Kim"
    (3 rows)

Based on the existing fields, it is also possible to add or update values for a given key using a concatenate-based method.
Here is the update of a key "author".

    postgres=# UPDATE products SET characs = characs || 'author=>Sarah'::hstore where id = 1;
    UPDATE 1
    postgres=# select * from products where id = 1;
     id |                                   characs                                   
    ----+-----------------------------------------------------------------------------
      1 | "date"=>"Dec 2012", "price"=>"500", "author"=>"Sarah", "currency"=>"dollar"
    (1 row)

If the key updated is not present in existing list, it is simply added as a new element.

You can also delete single elements.

    postgres=# UPDATE products SET characs = delete(characs,'price') where id = 1;
    UPDATE 1
    postgres=# select * from products where id = 1;
     id |                           characs                           
    ----+-------------------------------------------------------------
      1 | "date"=>"Dec 2012", "author"=>"Sarah", "currency"=>"dollar"
    (1 row)

SELECT query can also use key-based scan. Here for instance this query looks for the products with less than 300 stocks.

    postgres=# SELECT id FROM products WHERE (characs->'stock')::int <= 300;
     id 
    ----
      2
    (1 row)

(OK, not the best way of doing for your application but this is just a scholar example!).

On top of that, hstore also supports gin and gist indexes for the operators @>, ?, ?& and ?, as well as btree and hash indexes for '='.

    postgres=# create index products_index on products(characs);
    CREATE INDEX

Hope this gives a good introduction to hstore.

