---
author: Michael Paquier
comments: true
date: 2012-02-21 01:10:24+00:00
layout: post
slug: serial-types-implemented-in-postgres-xc
title: SERIAL types implemented in Postgres-XC
wordpress_id: 773
categories:
- PostgreSQL-2
tags:
- cluster
- database
- framework
- implementation
- incrementation
- pgxc
- postgres
- postgres-xc
- postgresql
- sequence
- serial
- table
- type
---

Just today this commit has happened in [Postgres-XC GIT repository](http://postgres-xc.git.sourceforge.net/git/gitweb-index.cgi).

    commit d09a42f2aac08a909ad9c23b534f11c6e7f16cee
    Author: Michael P <michael@otacoo.com>
    Date:   Tue Feb 21 09:02:04 2012 +0900

    Support for SERIAL types

    SERIAL columns in table use default values based on nextval of sequences
    to auto-generate values. In vanilla Postgres, table creation with serial
    column(s) is made with the following process:
    1 - Create sequence(s)
    2 - Create table
    3 - Alter sequence(s) to change it as being owned by the column of table
    previously created to manage object dependency.

    In Postgres-XC, the sequence creation is made such as the object is created
    on all the nodes, so a boolean flag associated to the serial process is
    added to bypass sequence creation on remote nodes in case a sequence is created
    within a serial process, and the query sent to remote nodes is the one given
    by client application and it is sent only once when table is created on local
    node.

    Regression tests are all updated in consequence.

This means that now serial types, used for auto-incrementing column values based on a sequence, are now available in Postgres-XC. This functionality is widely used by framework applications, so this is really an asset for the coming release. Here is a short demonstration.

    postgres=# create table aa (a serial, b varchar(10));
    NOTICE:  CREATE TABLE will create implicit sequence "aa_a_seq" for serial column "aa.a"
    CREATE TABLE
    postgres=# insert into aa (b) values ('aaa');
    INSERT 0 1
    postgres=# insert into aa (b) values ('bbb');
    INSERT 0 1
    postgres=# insert into aa (b) values ('ccc');
    INSERT 0 1
    postgres=# select * from aa;
     a |  b  
    ---+-----
     1 | aaa
     2 | bbb
     3 | ccc
    (3 rows)
    postgres=# \d
               List of relations
     Schema |   Name   |   Type   |  Owner  
    --------+----------+----------+---------
     public | aa       | table    | michael
     public | aa_a_seq | sequence | michael
    (2 rows)
    postgres=# \d aa
                                    Table "public.aa"
     Column |         Type          |                   Modifiers                    
    --------+-----------------------+------------------------------------------------
     a      | integer               | not null default nextval('aa_a_seq'::regclass)
     b      | character varying(10) | 

Enjoy!
