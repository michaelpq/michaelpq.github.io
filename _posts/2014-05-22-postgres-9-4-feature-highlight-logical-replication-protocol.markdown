---
author: Michael Paquier
lastmod: 2014-05-22
date: 2014-05-22 5:28:17+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-logical-replication-protocol
title: 'Postgres 9.4 feature highlight: Logical replication protocol'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- 9.4
- new
- feature
- replication
- logical
- protocol
- start
- slot
---
When developing a logical change receiver with the new [logical decoding]
(http://www.postgresql.org/docs/devel/static/logicaldecoding.html) facility
of Postgres 9.4, there are a couple of new commands and a certain libpq
protocol to be aware of before beginning any development for a logical
replication receiver (on top of knowing some [basics]
(/postgresql-2/postgres-9-4-feature-highlight-basics-logical-decoding/)
and what is an [output decoder plugin]
(/postgresql-2/postgres-9-4-feature-highlight-output-plugin-logical-replication/)).
Here is an exhaustive list of the commands to know.

### CREATE_REPLICATION_SLOT

This command can be used to create a logical replication slot (as well as
a physical replication slot). Here is an example using an output plugin
called [decoder_raw](https://github.com/michaelpq/pg_plugins/tree/master/decoder_raw)
using a replication connection:

    $ psql "replication=database" \
        -c "CREATE_REPLICATION_SLOT custom_slot LOGICAL decoder_raw"
      slot_name  | consistent_point | snapshot_name | output_plugin 
    -------------+------------------+---------------+---------------
     custom_slot | 0/16CC080        | 000003E9-1    | decoder_raw
    (1 row)

When running this query, be sure that the result is make of 1 tuple with
4 fields (respectively PQntuples and PQnfields)! Then, the new slot can
then be found listed on the server:

    $ psql -c "SELECT slot_name, plugin, restart_lsn FROM pg_replication_slots"
      slot_name  |   plugin    | restart_lsn 
    -------------+-------------+-------------
     custom_slot | decoder_raw | 0/16CC048
    (1 row)

This can be done as well with pg\_create\_logical\_replication\_slot with a
non-replication connection.

### DROP_REPLICATION_SLOT

This command is used to drop a replication slot,simply like this for
example:

    $ psql "replication=database" -c "DROP_REPLICATION_SLOT custom_slot"
    SELECT
    $ psql -c "SELECT plugin, restart_lsn FROM pg_replication_slots WHERE slot_name = 'custom_slot'"
     plugin | restart_lsn 
    --------+-------------
    (0 rows)

After running this command, this result obtained has no tuples and no
fields... Drop operation can be done as well with pg\_drop\_replication\_slot
using a normal connection to server.

### START_REPLICATION

This command already exists in versions of PostgreSQL older than 9.4, it has
been extended for the needs of logical replication. For example, to start
logical replication from a certain LSN using the slot created above, a command
like that sent through a replication slot is enough.
 like that in the case of
the slot created above:

    START_REPLICATION SLOT custom_slot LOGICAL restart_lsn;

restart_lsn can be used to specify from which point logical replication
begins. With a given decoding plugin, you can as well pass custom options.
Here is an example with decoder_raw:

    START_REPLICATION SLOT custom_slot LOGICAL restart_lsn ("include-transaction" 'off');

This command will send back a response of type PGRES_COPY_BOTH, containing
data that can be retrieved with [PQgetCopyData]
(http://www.postgresql.org/docs/devel/static/libpq-copy.html#LIBPQ-COPY-RECEIVE),
so it is not something that for example psql directly support or you may
finish with an error of this type:

    unexpected PQresultStatus: 8

Before rushing into coding, have a look at pg_recvlogical. It can provide a
good base for developing a custom receiver.
