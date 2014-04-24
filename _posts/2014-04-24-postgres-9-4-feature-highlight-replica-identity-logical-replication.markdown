---
author: Michael Paquier
comments: true
lastmod: 2014-04-24
date: 2014-04-24 13:53:43+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-replica-identity-logical-replication
title: 'Postgres 9.4 feature highlight: REPLICA IDENTITY and logical replication'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.4
- open source
- database
- logical
- decoding
- replication
- identity
- replica
- index
- delete
- update
- table
- relation
- copy
- transfer
---
Among the many things to say about logical replication features added in
PostgreSQL 9.4, [REPLICA IDENTITY](http://www.postgresql.org/docs/devel/static/sql-altertable.html)
is a new table-level parameter that can be used to control the information
written to WAL to identify tuple data that is being deleted or updated
(an update being a succession of an insert and a delete in MVCC).

This parameter has 4 modes:

  * DEFAULT
  * USING INDEX index
  * FULL
  * NOTHING

First let's set up an environment using some of the instructions
in a previous post dealing with some [basics of logical decoding]
(/postgresql-2/postgres-9-4-feature-highlight-basics-logical-decoding)
to set up a server using [test_decoding]
(http://www.postgresql.org/docs/devel/static/test-decoding.html) in a
replication slot.

    =# SELECT * FROM pg_create_logical_replication_slot('my_slot', 'test_decoding');
     slotname | xlog_position 
    ----------+---------------
     my_slot  | 0/16CB0F8
    (1 row)

The replication slot used here will be used in combination with
pg\_logical\_slot\_get\_changes to consume each change of the slot (to
compare with pg\_logical\_slot\_peek\_changes that can be used to view
the changes but not consume them).

In the case of DEFAULT, old tuple data is only identified with the primary
key of the table. This data is written into WAL only when at least one
column of the primary key is updated. Columns that are not part of the
primary key do not have their old value written.

    =# CREATE TABLE aa (a int, b int, c int, PRIMARY KEY (a, b));
    CREATE TABLE
    =# INSERT INTO aa VALUES (1,1,1);
    INSERT 0 1
    =# [ ... Clean up of slot information up to now ... ]
    =# UPDATE aa SET c = 3 WHERE (a, b) = (1, 1);
    UPDATE 1
    =# SELECT * FROM pg_logical_slot_get_changes('my_slot', NULL, NULL);
     location  | xid  |                              data                               
    -----------+------+-----------------------------------------------------------------
     0/1728D50 | 1013 | BEGIN 1013
     0/1728D50 | 1013 | table public.aa: UPDATE: a[integer]:1 b[integer]:1 c[integer]:3
     0/1728E70 | 1013 | COMMIT 1013
    (3 rows)
    =# UPDATE aa SET a = 2 WHERE (a, b) = (1, 1);
    UPDATE 1
    =# SELECT * FROM pg_logical_slot_get_changes('my_slot', NULL, NULL);
     location  | xid  |                                                     data                                                      
    -----------+------+---------------------------------------------------------------------------------------------------------------
     0/1728EA8 | 1014 | BEGIN 1014
     0/1728EA8 | 1014 | table public.aa: UPDATE: old-key: a[integer]:1 b[integer]:1 new-tuple: a[integer]:2 b[integer]:1 c[integer]:3
     0/1728FF0 | 1014 | COMMIT 1014
    (3 rows)

Ît is important to know that REPLICA IDENTITY can only be changed using
ALTER TABLE, and that the parameter value is only viewable with '\d+'
only if default behavior is not used. Also, after creating a table, REPLICA
IDENTITY is set to DEFAULT (Surprise!).

    =# \d+ aa
                              Table "public.aa"
     Column |  Type   | Modifiers | Storage | Stats target | Description 
    --------+---------+-----------+---------+--------------+-------------
     a      | integer | not null  | plain   |              | 
     b      | integer | not null  | plain   |              | 
     c      | integer |           | plain   |              | 
    Indexes:
        "aa_pkey" PRIMARY KEY, btree (a, b)
    =# ALTER TABLE aa REPLICA IDENTITY FULL;
    ALTER TABLE
    =# \d+ aa
                              Table "public.aa"
     Column |  Type   | Modifiers | Storage | Stats target | Description 
    --------+---------+-----------+---------+--------------+-------------
     a      | integer | not null  | plain   |              | 
     b      | integer | not null  | plain   |              | 
     c      | integer |           | plain   |              | 
    Indexes:
        "aa_pkey" PRIMARY KEY, btree (a, b)
    Replica Identity: FULL
    =# [ ... Replication slot changes are consumed here ... ]

In the case of FULL, all the column values are written to WAL all the time.
This is the most verbose, and as well the most resource-consuming mode. Be
careful here particularly for heavily-updated tables.

    =# UPDATE aa SET c = 4 WHERE (a, b) = (2, 1);
    UPDATE 1
    =# SELECT * FROM pg_logical_slot_get_changes('my_slot', NULL, NULL);
     location  | xid  |                                                            data                                                            
    -----------+------+----------------------------------------------------------------------------------------------------------------------------
     0/172EC70 | 1016 | BEGIN 1016
     0/172EC70 | 1016 | table public.aa: UPDATE: old-key: a[integer]:2 b[integer]:1 c[integer]:3 new-tuple: a[integer]:2 b[integer]:1 c[integer]:4
     0/172EE00 | 1016 | COMMIT 1016

On the contrary, NOTHING prints... Nothing. (Note: operation done after
an appropriate ALTER TABLE and after consuming replication slot information).

    =# UPDATE aa SET c = 4 WHERE (a, b) = (2, 1);
    UPDATE 1
    =# SELECT * FROM pg_logical_slot_get_changes('my_slot', NULL, NULL);
     location  | xid  |                              data                               
    -----------+------+-----------------------------------------------------------------
     0/1730F58 | 1018 | BEGIN 1018
     0/1730F58 | 1018 | table public.aa: UPDATE: a[integer]:2 b[integer]:1 c[integer]:4
     0/1731100 | 1018 | COMMIT 1018

Finally, there is USING INDEX, which writes to WAL the values of the index
defined with this option. The index needs to be unique, cannot contain
expressions and must contain NOT NULL columns.

    =# ALTER TABLE aa ALTER COLUMN c SET NOT NULL;
    ALTER TABLE
    =# CREATE unique INDEX aai on aa(c);
    CREATE INDEX
    =# ALTER TABLE aa REPLICA IDENTITY USING INDEX aai;
    ALTER TABLE
    =# [ ... Consuming all information from slot ... ]
    =# UPDATE aa SET c = 5 WHERE (a, b) = (2, 1);
    UPDATE 1
    =# SELECT * FROM pg_logical_slot_get_changes('my_slot', NULL, NULL);
     location  | xid  |                                               data                                               
    -----------+------+--------------------------------------------------------------------------------------------------
     0/1749A68 | 1029 | BEGIN 1029
     0/1749A68 | 1029 | table public.aa: UPDATE: old-key: c[integer]:4 new-tuple: a[integer]:2 b[integer]:1 c[integer]:5
     0/1749D40 | 1029 | COMMIT 1029
    (3 rows)

Note that in this case the primary key information is not decoded, only
the NOT NULL column c that the index covers.

REPLICA IDENTITY should be chosen carefully for each table of a given
application, knowing that for example FULL generates an extra amount
of WAL that may not be necessary, NOTHING may forget about essential
information. In most of the cases, DEFAULT provides a good cover though.
