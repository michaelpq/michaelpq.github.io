---
author: Michael Paquier
comments: true
date: 2013-02-19 00:25:55+00:00
layout: post
slug: postgres-contrib-module-highlight-pageinspect
title: 'Postgres contrib module highlight: pageinspect'
wordpress_id: 1667
categories:
- PostgreSQL-2
tags:
- check
- contrib
- database
- inspection
- max
- min
- module
- mvcc
- open source
- page
- pageinspect
- postgres
- postgresql
- relation
- scan
- transaction
- tuple
- visibility
---

[pageinspect](http://www.postgresql.org/docs/9.2/static/pageinspect.html) is an extension module of PostgreSQL core allowing to have a look at the contents of relations (index or table) in the database at a low level. In the case of PostgreSQL, tuples of a table are stored in blocks of data whose size can be changed with --with-blocksize at configure step. This module is particularly useful for debugging when implementing a new functionality that changes visibility of data like what could do an autovacuum or map visibility feature, or simply to understand the internals of Postgres without having to read much codea .

Without entering in details in the page and page item structures, be sure to have a look at the documentation about [database page layout](http://www.postgresql.org/docs/9.2/static/storage-page-layout.html).

In order to install this module for the source tree, simply do the following.

    cd $POSTGRES_ROOT/contrib/pageinspect
    make install

Once done, the following files are installed in the share/ folder of your installation path.

    pageinspect--1.0.sql  pageinspect--unpackaged--1.0.sql  pageinspect.control

Since PostgreSQL 9.1, it is necessary to use CREATE EXTENSION to finish the installation of the module. Hence connect to the database and run the following SQL command.

    postgres=# CREATE EXTENSION pageinspect;
    CREATE EXTENSION

By doing that the following objects are created in 

    postgres=# \dx+ pageinspect
        Objects in extension "pageinspect"
                Object Description            
    ------------------------------------------
     function bt_metap(text)
     function bt_page_items(text,integer)
     function bt_page_stats(text,integer)
     function fsm_page_contents(bytea)
     function get_raw_page(text,integer)
     function get_raw_page(text,text,integer)
     function heap_page_items(bytea)
     function page_header(bytea)
    (8 rows)

In those functions, get_raw_page is the most important one because it allows fetching a raw page of data for a given relation. Its output is not that useful as-is, it is however possible to deparse its output to get various readable information.

  * page_header gives information about the page header with general information like the log sequence number (LSN, WAL number) of the last change done on the page, or information about remaining space on page based on its upper and lower offset, tuples item pointer being stored from the top of the page and tuple data+header being stored at the bottom of the page
  * get_raw_page gives information about the tuple items, I'll come back to that in more details later in this post
  * fsm_page_contents gives an output of the FSM (freespace map, used to locate quickly on which page a tuple can be stored based on the free space available)

There are also additional functions helping to vizualize information about b-trees with bt_metap, bt_page_items and bt_page_stats.

What I really wanted to show in this post is how you can use pageinspect to visualize the changes on your database if you do some simple DML or maintenance operations. So let's take an example:

    postgres=# CREATE TABLE aa AS SELECT 1 AS a;
    SELECT 1

Table aa being a fresh relation, its first record has been added in the first page of the relation storage.

    postgres=# SELECT lp, lp_len, t_xmin, t_xmax, lp_off from heap_page_items(get_raw_page('aa', 0));
     lp | lp_len | t_xmin | t_xmax | lp_off 
    ----+--------+--------+--------+--------
      1 |     28 |    685 |      0 |   8160
    (1 row)

When doing an INSERT command, what PostgreSQL does is setting the minimum transaction ID from where the tuple becomes visible for other session backends.

Then, how is used the space available on the page? It is possible to know more about that by having a look at the global page information with page_header.

    postgres=# SELECT * from page_header(get_raw_page('aa', 0));
        lsn    | tli | flags | lower | upper | special | pagesize | version | prune_xid 
    -----------+-----+-------+-------+-------+---------+----------+---------+-----------
     0/178D500 |   1 |     0 |    28 |  8160 |    8192 |     8192 |       4 |         0
    (1 row)

A page structure in PostgreSQL is particular. At the top of the page 28 bytes are used for the page header information (PageHeaderData in bufpage.h). From the top, item pointers (ItemPointer) of 4 bytes are used for each tuple entry to redirect to the place on page where tuple is located. Tuple header and tuple data are actually stored at the bottom of the page, their length may vary depending on the data stored. 

In the case of the first record "1" of table aa, the lower offset is defined at 28 (position of pointer on page, just after the 28 bytes of the page header). The upper offset shows that 32 bytes are used to store 28 bytes of data and 4 bytes of header. By inserting a second tuple "2", here is what happens:

    postgres=# SELECT * from page_header(get_raw_page('aa', 0));
        lsn    | tli | flags | lower | upper | special | pagesize | version | prune_xid 
    -----------+-----+-------+-------+-------+---------+----------+---------+-----------
     0/17A1B90 |   1 |     0 |    32 |  8128 |    8192 |     8192 |       4 |         0
    (1 row)

4 bytes of ItemPointer data has been added on top of the page and 32 bytes are added to the bottom for the tuple data and header.

After the secind tuple insertion, here is how the page changed.

     postgres=# SELECT lp, lp_len, t_xmin, t_xmax, lp_off from heap_page_items(get_raw_page('aa', 0));
     lp | lp_len | t_xmin | t_xmax | lp_off 
    ----+--------+--------+--------+--------
      1 |     28 |    685 |      0 |   8160
      2 |     28 |    687 |      0 |   8128
    (2 rows)

In the case of a DELETE, what is done is to update in the page t_xmax for the tuple entry, maximum transaction ID where the tuple is visible.

    postgres=# DELETE FROM aa WHERE a = 2;
    DELETE 1
    postgres=# SELECT lp, lp_len, t_xmin, t_xmax, lp_off from heap_page_items(get_raw_page('aa', 0));
     lp | lp_len | t_xmin | t_xmax | lp_off 
    ----+--------+--------+--------+--------
      1 |     28 |    685 |      0 |   8160
      2 |     28 |    687 |    688 |   8128
    (2 rows)

For an UPDATE, what actually happens is an INSERT and a DELETE, a new entry is added in page with a fresh t_min, and the old tuple entry has its t_max updated.

    postgres=# UPDATE aa SET a = 3 WHERE a = 1;
    UPDATE 1
    postgres=# SELECT lp, t_ctid, lp_len, t_xmin, t_xmax, lp_off from heap_page_items(get_raw_page('aa', 0));
     lp | t_ctid | lp_len | t_xmin | t_xmax | lp_off 
    ----+--------+--------+--------+--------+--------
      1 | (0,3)  |     28 |    685 |    689 |   8160
      2 | (0,2)  |     28 |    687 |    688 |   8128
      3 | (0,3)  |     28 |    689 |      0 |   8096
    (3 rows)

Note also that the CTID of the tuple indicating the couple (pagenumber, tuple position) of the old tuple has been changed to indicate the new tuple inserted.

A last thing, what happens on those pages when performing a VACUUM?

    postgres=# vacuum aa;
    VACUUM
    postgres=# SELECT lp, t_ctid, lp_len, t_xmin, t_xmax, lp_off from heap_page_items(get_raw_page('aa', 0));
     lp | t_ctid | lp_len | t_xmin | t_xmax | lp_off 
    ----+--------+--------+--------+--------+--------
      1 |        |      0 |        |        |      3
      2 |        |      0 |        |        |      0
      3 | (0,3)  |     28 |    689 |      0 |   8160
    (3 rows)
    postgres=# SELECT * from page_header(get_raw_page('aa', 0));
        lsn    | tli | flags | lower | upper | special | pagesize | version | prune_xid 
    -----------+-----+-------+-------+-------+---------+----------+---------+-----------
     0/17A3FA8 |   1 |     5 |    36 |  8160 |    8192 |     8192 |       4 |         0
    (1 row)

When running the VACUUM on relation 'aa', my session was the only one on the server, so what has been done is removing the tuples seen as dead, as no other sessions would need them. Hence tuple entries 1 and 2 are simply removed and can be used for new fresh tuples. Note also the new value of flags for the page header, before it was set to 1 and now it became 5. In this case the page is set as PD_ALL_VISIBLE, meaning that all the tuples are visible to all the backends.
