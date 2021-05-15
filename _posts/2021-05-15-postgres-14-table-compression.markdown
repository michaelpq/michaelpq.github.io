---
author: Michael Paquier
lastmod: 2021-05-15
date: 2021-05-15 13:06:22+00:00
layout: post
type: post
slug: postgres-14-table-compression
title: 'Postgres 14 highlight - CREATE TABLE COMPRESSION'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 14
- table
- materialized
- view
- compression

---

It has been some time since something has been posted on this blog, and here
is a short story about the following
[commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=bbe0a81db69bd10bd166907c3701492a29aca294),
for a feature that will land in the upcoming version 14 of PostgreSQL:

    commit: bbe0a81db69bd10bd166907c3701492a29aca294
    author: Robert Haas <rhaas@postgresql.org>
    date: Fri, 19 Mar 2021 15:10:38 -0400
    Allow configurable LZ4 TOAST compression

    There is now a per-column COMPRESSION option which can be set to pglz
    (the default, and the only option in up until now) or lz4. Or, if you
    like, you can set the new default_toast_compression GUC to lz4, and
    then that will be the default for new table columns for which no value
    is specified. We don't have lz4 support in the PostgreSQL code, so
    to use lz4 compression, PostgreSQL must be built --with-lz4.

    [...]

    Dilip Kumar. The original patches on which this work was based were
    written by Ildus Kurbangaliev, and those were patches were based on
    even earlier work by Nikita Glukhov, but the design has since changed
    very substantially, since allow a potentially large number of
    compression methods that could be added and dropped on a running
    system proved too problematic given some of the architectural issues
    mentioned above; the choice of which specific compression method to
    add first is now different; and a lot of the code has been heavily
    refactored.  More recently, Justin Przyby helped quite a bit with
    testing and reviewing and this version also includes some code
    contributions from him. Other design input and review from Tomas
    Vondra, Álvaro Herrera, Andres Freund, Oleg Bartunov, Alexander
    Korotkov, and me.

    Discussion: http://postgr.es/m/20170907194236.4cefce96%40wp.localdomain
    Discussion: http://postgr.es/m/CAFiTN-uUpX3ck%3DK0mLEk-G_kUQY%3DSNOTeqdaNRR9FMdQrHKebw%40mail.gmail.com

Storing large values in Postgres is addressed with the concept of
[TOAST](https://www.postgresql.org/docs/devel/storage-toast.html), that
basically compresses the data value using a compression algorithm proper
to PostgreSQL called pglz (from src/common/pg\_lzcompress.c in the code
tree for its APIs).  This compression method is old enough to vote, though
that depends on your own country, coming from commit
[79c3b71c](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=79c3b71c1be3a79ec2d1f4d64bdef13f0e0a086a)
of 1999 by Jan Wieck, and it is easily outclassed with more recent
compression algorithms with pglz being a huge CPU consumer.  The commit
mentioned above gives users an alternative to the compression method that
can be used for TOAST compression, with [LZ4](https://github.com/lz4/lz4),
known to offer good compromises in terms of compression and speed.

In order to enable this option, note first that it is necessary to build
the code with the configure option --with-lz4, meaning that compilation
is going to require an extra development package like liblz4-dev.

This option can only be applied to data types on which toast compression
would apply, and [CREATE TABLE](https://www.postgresql.org/docs/devel/sql-createtable.html)
has gained a new column-level clause called COMPRESSION, that can be set
to two values: "pglz" or "lz4".  For example (note that \d+ shows the
compression method used by each column):

    =# CREATE TABLE tab_compression (
         a text COMPRESSION pglz,
         b text COMPRESSION lz4);
    CREATE TABLE
    =# \d+ tab_compression
                                        Table "public.tab_compression"
     Column | Type | Collation | Nullable | Default | Storage  | Compression | Stats target | Description
    --------+------+-----------+----------+---------+----------+-------------+--------------+-------------
     a      | text |           |          |         | extended | pglz        |              |
     b      | text |           |          |         | extended | lz4         |              |
    Access method: heap

It is worth noting that psql has an option called HIDE\_TOAST\_COMPRESSION,
to be able to hide the compression method used, similarly to HIDE\_TABLEAM
for the access method.  This is useful for extension developers aiming at
making portable tests.

This feature comes with a GUC called
[default\_toast\_compression](https://www.postgresql.org/docs/devel/runtime-config-client.html#RUNTIME-CONFIG-CLIENT-STATEMENT)
that is user-settable.  Its default value is "pglz", and this is used
as the default compression method by any attribute where COMPRESSION is
not specified.

[ALTER TABLE](https://www.postgresql.org/docs/devel/sql-altertable.html)
also comes with its own way to enforce the compression method used by an
attribute, but note that this does not change any values already compressed
in a specific way, and this takes effect only for new values (VACUUM FULL
could be used here).  The new function pg\_column\_compression(), that gives
the compression method used by a given value, is useful here:

    =# CREATE TABLE tab_compression_2 (id int, data text COMPRESSION pglz);
    CREATE TABLE
    =# INSERT INTO tab_compression_2 VALUES(1, repeat('1234567890', 1000));
    INSERT 0 1
    =# ALTER TABLE tab_compression_2 ALTER COLUMN data SET COMPRESSION lz4;
    ALTER TABLE
    =# INSERT INTO tab_compression_2 VALUES(2, repeat('1234567890', 1000));
    INSERT 0 1
    =# SELECT id, pg_column_compression(data) FROM tab_compression_2;
     id | pg_column_compression
    ----+-----------------------
      1 | pglz
      2 | lz4
    (2 rows)

The same concept applies to CREATE TABLE AS or SELECT INSERT, where values
already compressed are stored into the relation without recompressing the
values for performance reasons.  So, even if a relation's attribute uses a
given compression method, it may finish with a mix of compression methods
used:

    =# CREATE TABLE tab_compression_3 AS SELECT * FROM tab_compression_2;
    SELECT 2
    =# SELECT id, pg_column_compression(data) FROM tab_compression_3;
     id | pg_column_compression
    ----+-----------------------
      1 | pglz
      2 | lz4
    (2 rows)
    =# SHOW default_toast_compression;
     default_toast_compression
    ---------------------------
     pglz
    (1 row)
    =# \d+ tab_compression_3
                                        Table "public.tab_compression_3"
     Column |  Type   | Collation | Nullable | Default | Storage  | Compression | Stats target | Description
    --------+---------+-----------+----------+---------+----------+-------------+--------------+-------------
     id     | integer |           |          |         | plain    |             |              |
     data   | text    |           |          |         | extended | pglz        |              |
    Access method: heap

The compression method used by the attributes of a table created by
[CREATE TABLE AS](https://www.postgresql.org/docs/devel/sql-createtableas.html)
or [SELECT INTO](https://www.postgresql.org/docs/devel/sql-selectinto.html)
cannot be enforced at grammar level.  So, the only solution is to use
default\_toast\_compression, which will set the same compression method for
all the attributes that require TOAST.  This can be enforced afterwards
with an ALTER TABLE query, which is useful with logical dumps, to make
sure that a restore will compress the data to the new compression method
as the dump includes the raw, uncompressed data.

Another thing to note is that pg\_dump has support for an option called
--no-toast-compression, to not dump the compression method used by
relations.  This can be really helpful to sanitize the compression method
used on a fresh cluster in combination with default\_toast\_compression.

[ALTER MATERIALIZED VIEW](https://www.postgresql.org/docs/devel/sql-altermaterializedview.html)
has support for a SET COMPRESSION clause, though its impact is limited,
per the same rules as CTAS, and REFRESH MATERIALIZED VIEW would copy to
the physical file used by the materialized view any already-compressed
values without any changes.

Speaking about replication, it is perfectly possible to replay on a
standby WAL records that include data compressed with LZ4 on a primary
via physical, streaming, replication, even if the PostgreSQL binaries
of the standby do *not* have support for LZ4.  Attempting to read such
values on the tables would simply result in an error.  Logical
replication, by applying changes, is not affected by that and would
compress the values to apply to a relation using its configured
compression method.

This is really a cool feature, glad to see this part of PostgreSQL 14 to
give more options to users.
