---
author: Michael Paquier
comments: true
lastmod: 2013-05-22
date: 2013-05-22 18:28:32+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-new-verbose-error-fields
title: 'Postgres 9.3 feature highlight: new verbose error fields'
wordpress_id: 1904
categories:
- PostgreSQL-2
tags:
- '9.3'
- additional
- client
- column
- constraint
- error
- feature
- field
- highlight
- improvement
- new
- number
- postgres
- postgresql
- psql
- table
- type
---

PostgreSQL is already pretty useful for application developers when returning to client error messages by providing a certain level of details with multiple distinct fields like the position of the code where the error occurred. However this was lacking with the database object names, forcing the client application to deparse the error string returned by server, generally with field 'M', to get more details about the objects that have been involved in the errors. This functionality has been added in PostgreSQL 9.3 thanks to this commit. 

    commit 991f3e5ab3f8196d18d5b313c81a5f744f3baaea
    Author: Tom Lane <tgl@sss.pgh.pa.us>
    Date:   Tue Jan 29 17:06:26 2013 -0500
    
    Provide database object names as separate fields in error messages.
    
    This patch addresses the problem that applications currently have to
    extract object names from possibly-localized textual error messages,
    if they want to know for example which index caused a UNIQUE_VIOLATION
    failure.  It adds new error message fields to the wire protocol, which
    can carry the name of a table, table column, data type, or constraint
    associated with the error.  (Since the protocol spec has always instructed
    clients to ignore unrecognized field types, this should not create any
    compatibility problem.)
    
    Support for providing these new fields has been added to just a limited set
    of error reports (mainly, those in the "integrity constraint violation"
    SQLSTATE class), but we will doubtless add them to more calls in future.
    
    Pavel Stehule, reviewed and extensively revised by Peter Geoghegan, with
    additional hacking by Tom Lane.

Thanks to this feature, it is possible to obtain more detailed information about the objects involved in an error by providing additional fields. This has as advantage to avoid having to deparse an error message string that could change, even slightly, between major releases, and to provide a centralized way to report errors. There are five new additional [error fields](http://www.postgresql.org/docs/devel/static/protocol-error-fields.html) introduced with this commit:

  * 's', schema name
  * 't', table name
  * 'c', column name
  * 'd', datatype name
  * 'n', constraint name

Note that those fields are used only for certain error codes involving those specific objects. You can have a look to the [error code appendix](http://www.postgresql.org/docs/devel/static/errcodes-appendix.html) for more details.

In order to be able to view the new fields, be sure to set up the error report verbosity to 'verbose'. With a psql client, you simply need to use this command:

    \set VERBOSITY verbose

This is particularly useful as default value in a development environment, so also feel free to set it in ~/.psqlrc if necessary.

So, let's now have a look at this feature with an extremely simple table using a primary key.

    postgres=# CREATE TABLE aa (a int PRIMARY KEY);
    CREATE TABLE
    postgres=# INSERT INTO aa VALUES (1);
    INSERT 0 1

Prior to 9.3, here is what you would get as error message when a primary key constraint is violated (9.2 stable branch code, 9.2.4+alpha):

    postgres=# INSERT INTO aa VALUES (1);
    ERROR:  23505: duplicate key value violates unique constraint "aa_pkey"
    DETAIL:  Key (a)=(1) already exists.
    LOCATION:  _bt_check_unique, nbtinsert.c:396

And Here is what you get with 9.3 (beta1):

    postgres=# INSERT INTO aa VALUES (1);
    ERROR:  23505: duplicate key value violates unique constraint "aa_pkey"
    DETAIL:  Key (a)=(1) already exists.
    SCHEMA NAME:  public
    TABLE NAME:  aa
    CONSTRAINT NAME:  aa_pkey
    LOCATION:  _bt_check_unique, nbtinsert.c:398

Note the presence of the fields 'SCHEMA NAME', 'TABLE NAME' and 'CONSTRAINT NAME' here.

Having such an additional output for psql is always useful in order to catch quickly the object causing the errors, but honestly this is far more useful for backend applications using an interface like libpq that manipulate error fields directly as it removes the necessity to apply some magic on the driver or application-side to deparse manually a given error message.
