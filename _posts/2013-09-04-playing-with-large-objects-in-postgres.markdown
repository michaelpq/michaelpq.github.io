---
author: Michael Paquier
comments: true
date: 2013-09-04 03:54:14+00:00
layout: post
type: post
slug: playing-with-large-objects-in-postgres
title: 'Playing with large objects in Postgres'
wordpress_id: 2006
categories:
- PostgreSQL-2
tags:
- 2gb
- 32
- 4tb
- 64
- 9.3
- big
- binary
- blob
- bytea
- close
- database
- huge
- large object
- lo
- object
- open
- open source
- postgres
- postgresql
- seek
- storage
- toast
- truncate
---
PostgreSQL has for ages a feature called [large objects](http://www.postgresql.org/docs/9.2/static/largeobjects.html) allowing to store in the database objects with a... Well... Large size. All those objects are stored in dedicated catalog tables called [pg\_largeobject\_metadata](http://www.postgresql.org/docs/devel/static/catalog-pg-largeobject-metadata.html) for general information like ownership and [pg\_largobject](http://www.postgresql.org/docs/devel/static/catalog-pg-largeobject.html) for the data itself, data divided into pages of 2kB (default size, defined as BLCKSZ/4). This feature got its major upgrade in 9.0 with the introduction of ownership of a large object and 9.3 with the maximum size of an object increased to 4TB. This maximum size was 2GB in versions prior to 9.2. One of the main advantages of a large object is its maximum size, which is particularly convenient compared for example to [TOAST](http://www.postgresql.org/docs/devel/static/storage-toast.html) whose maximum size is 1GB (an internal storage system that stores objects larger than a single page, usually 8kB).

Postgres has many functions and even APIs to manage large objects in servers. Here is an exhaustive list accessible though psql:

    =# \dfS lo_*
                                     List of functions
       Schema   |     Name      | Result data type |    Argument data types    |  Type  
    ------------+---------------+------------------+---------------------------+--------
     pg_catalog | lo_close      | integer          | integer                   | normal
     pg_catalog | lo_creat      | oid              | integer                   | normal
     pg_catalog | lo_create     | oid              | oid                       | normal
     pg_catalog | lo_create     | oid              | oid, bytea                | normal
     pg_catalog | lo_export     | integer          | oid, text                 | normal
     pg_catalog | lo_get        | bytea            | oid                       | normal
     pg_catalog | lo_get        | bytea            | oid, bigint, integer      | normal
     pg_catalog | lo_import     | oid              | text                      | normal
     pg_catalog | lo_import     | oid              | text, oid                 | normal
     pg_catalog | lo_lseek      | integer          | integer, integer, integer | normal
     pg_catalog | lo_lseek64    | bigint           | integer, bigint, integer  | normal
     pg_catalog | lo_open       | integer          | oid, integer              | normal
     pg_catalog | lo_put        | void             | oid, bigint, bytea        | normal
     pg_catalog | lo_tell       | integer          | integer                   | normal
     pg_catalog | lo_tell64     | bigint           | integer                   | normal
     pg_catalog | lo_truncate   | integer          | integer, integer          | normal
     pg_catalog | lo_truncate64 | integer          | integer, bigint           | normal
     pg_catalog | lo_unlink     | integer          | oid                       | normal
    (18 rows)

There is as well an [ALTER LARGE OBJECT](http://www.postgresql.org/docs/devel/static/sql-alterlargeobject.html) to change the permission access of a given large object to a new owner. Note also that there are two addition APIs not available directly in an SQL client called lo\_read and lo\_write to respectively read from and write to a large object.

Now, let's see how to manipulate a large object with a simple example: a short [lorem ipsum](http://en.wikipedia.org/wiki/Lorem_ipsum). OK this is not large in size but it is enough to demonstrate how to use large object functions... Here is the text:

    Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod
    tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim
    veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex
    ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate
    velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat
    cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id
    est laborum.

The creation a large object with no data can be done with lo\_create or lo\_creat.

    =# SELECT lo_create(0);
     lo_create
    -----------
         16385
    (1 row)

When creating a new object, you should specify InvalidOid (or 0 with a psql client) such as the server will assign by itself a new OID for this object. This way you also don't need to worry about breaking the uniqueness of large objects OIDs. The information of a new large object is located in pg\_largeobject_metadata. Note that this does not create anything in pg\_largeobject this object has no data yet, the purpose here is to create a valid ID usable for later operations with a defined owner.

Now let's import an object to database with lo\_import (the Lorem Ipsum showed previously).

    =# select lo_import('/path/to/file/lorem.txt');
     lo_import
    -----------
         16386
    (1 row)
    =# select loid from pg_largeobject;
      loid
    -------
     16386
    (1 row)

In this case also, server has assigned automatically a new OID for the object as importing an object implies its creation on server side.

Once an object has been uploaded to a server, you can open it with lo\_open. Don't forget that all the large object operations with a file descriptor must happen inside a transaction block. So be sure to begin a transaction block. So for a read/write open, here it is:

    =# select lo_open(16386, x'60000'::int);
     lo_open
    ---------
           0
    (1 row)

Here are the flags you can use on large objects when opening them, explaining the value used in the query above:

    #define INV_WRITE 0x00020000 /* Write access */
    #define INV_READ 0x00040000 /* Read access */

Large objects are automatically closed when the transaction that opens them commits. The same operation can be done with lo\_close.

Moving the position of the file descriptor is possible with lo\_lseek. For example here is how to move it from the beginning of the large object:

    =# select lo_lseek(0, 50, 0);
     lo_lseek
    ----------
          50
    (1 row)

And here is how to move from the current position.

    =# select lo_lseek(0, 50, 1);
     lo_lseek
    ----------
         100
    (1 row)

The returned result corresponds to the current position of the file descriptor.

When using lo\_lseek, the second argument is an offset conditioned by the third argument that needs to be one of the values below indicating an fseek flag. The first argument is simply the file descriptor obtained when opening the large object.

    #define SEEK_SET 0 /* Seek from beginning of file. */
    #define SEEK_CUR 1 /* Seek from current position. */
    #define SEEK_END 2 /* Seek from end of file */

Here are a couple of extra things important to remember as well:

  * lo\_tell reports the current location on the file descriptor.
  * lo\_lseek64, lo\_tell64 and lo\_truncate64 are functions newly introduced in 9.3 to interact with large object with a size higher than 2GB.

Using a psql client, it is as well possible to perform a truncate operation on a large object from a psql client. Here is for example how to reduce the last lorem ipsum text to 20 bytes.

    =# select lo_truncate(0, 20);
     lo_truncate
    -------------
             0
    (1 row)

If the large object is truncated with a size value higher than its actual size, the truncation is completed with '\0? for all the remaining bytes. Hence, you can use truncation for example to initialize a large object with no data to something with a wanted size having only '?0?.

When trying to truncate a large object with only a read permission, here is what happens...

    =# begin;
    BEGIN
    =# select lo_open(16386, x'40000'::int);
     lo_open
    ---------
          0
    (1 row)
    =# select lo_truncate(0, 5);
    ERROR: 55000: large object descriptor 0 was not opened for writing
    LOCATION: lo_truncate_internal, be-fsstubs.c:590

Then let's export a large object out of the database server. This operation does not need to be run in a transaction block.

    =# select lo_export(16386, '/path/to/file/lorem2.txt');
     lo_export
    -----------
           1
    (1 row)

This operation returns 1 for a success and -1 for a failure.

And here is what happened to the Lorem Ipsum after the truncation done previously.

    $ head /path/to/file/lorem2.txt ; echo ""
    Lorem ipsum dolor si

Finally deleting a large object from a server can be achieved with lo\_unlink.

    =# select lo_unlink(16386);
     lo_unlink
    -----------
            1
    (1 row)

This will drop from server the information as well as the data of the large object.

Will all the basics presented here you should be able to apprehend how to manipulate large objects. Also, don't forget that lo\_read and lo\_write are an important part of the interface to control large objects. So go ahead and try them!
