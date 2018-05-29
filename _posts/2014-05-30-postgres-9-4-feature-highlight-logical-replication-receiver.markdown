---
author: Michael Paquier
lastmod: 2014-05-30
date: 2014-05-30 13:35:29+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-logical-replication-receiver
title: 'Postgres 9.4 feature highlight - Logical replication receiver'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.4
- logical
- replication
- receiver

---
These last couple of days I have been developing for studies a background
worker able to fetch changes from a logical decoder already developed
and presented on this blog called [decoder\_raw]
(https://github.com/michaelpq/pg_plugins/tree/master/decoder_raw) able
to generate raw queries based on the logical changes decoded on server
from its WAL. This receiver, called [receiver\_raw]
(https://github.com/michaelpq/pg_plugins/tree/master/receiver_raw)
runs as a background worker that connects to a node running decoder_raw
using a replication connection and then fetches decoded logical changes
from it, which are in this case ready-to-be-applied raw queries. Those
changes are then applied on the database one by one using the [SPI]
(https://www.postgresql.org/docs/devel/static/spi.html) through  a loop
process that sleeps during a customizable amount of nap time. Note that
receiver\_raw is actually designed to be performant as it applies one single
batch of changes using only one transaction in a single loop process.
That's the best doable particularly for long transactions.

By the way, here are a couple of things to be aware of when developing
your own logical change receiver.

#### Connection string

The [connection string]
(https://www.postgresql.org/docs/devel/static/libpq-connect.html#LIBPQ-CONNSTRING)
that is being used to connect to the remote node should have the following
shape at minimum to set up a replication connection:

    replication=database dbname=postgres

Then it is only a matter of calling PQconnectdb or PQconnectdbParams to
connect to the database.

#### Initialization of logical replication

There are a couple of things to remember here:

  * It is possible to precise 0/0 as a start position for the logical
replication to let the server manage the start point.
  * Passing options is possible at this point to customize the data
received from the decoder or to put restrictions on it.
  * Initialization is done with the COPY protocol

You would then finish with something like that:

    PQExpBuffer query;
    PGconn *conn;
    PGresult *res;

    /* Query buffer for remote connection */
    query = createPQExpBuffer();

    /* Start logical replication at specified position */
    appendPQExpBuffer(query, "START_REPLICATION SLOT \"%s\" LOGICAL 0/0 "
                             "(\"include_transaction\" 'off')",
                      receiver_slot);
    res = PQexec(conn, query->data);
    if (PQresultStatus(res) != PGRES_COPY_BOTH)
    {
        PQclear(res);
        ereport(LOG, (errmsg("Could not start logical replication")));
        proc_exit(1);
    }
    PQclear(res);
    resetPQExpBuffer(query);

#### Fetching changes

Now that the initialization has been done, you can enter in the main
processing loop and fetch the changes. This consists simply in calling
PQgetCopyData to fetch a single change and then to do some processing
depending on the quantity of data fetched:

  * 0, nothing has been fetched, so move on to the next loop
  * -1, the end of the COPY stream
  * -2, an error occurred
  * In all the other cases there is some data to treat

When there is data the receiver can get two types of message:

  * 'k' for a keepalive message. Receiver should send feedback at this
point.
  * 'w' for a stream message with some change data in it.

Both message follow a particular format, and contain information about
the WAL position of remote server or the time when change has been sent
for example. Using Postgres core code, having a look at pg\_recvlogical
is a good start. Note that receiver_raw does its job as well.

#### Strengthen inter-node communication with WAL position feedback

It is really important to have the logical receiver tell back to the
remote server what is the LSN position (or WAL position if you want)
that it has already written and flushed. If the receiver does not do
that, remote server will retain WAL files that are perhaps not
necessary anymore, blowing the amount of space dedicated to WAL, something
particularly painful when WAL files are on a dedicated partition whose
size may be limited. Also when the receiver reinitializes a logical
replication protocol, past changes will be fetched again... The best
thing to have a receiver send feedback is to have a look at the function
called SendFeedback in src/bin/pg_basebackup/receivelog.c, and simply
copy/paste it to your code. You won't regret it.
 
#### An example

Now is finally game time, with a simple example using two nodes. A first
node listening to port 5432 runs the logical decoder decoder\_raw.
A logical slot has been created on it, under the database "postgres".

    $ psql -p 5432 postgres \
       -c 'SELECT slot_name FROM pg_create_logical_replication_slot('slot', 'decoder_raw');
     slot_name 
    -----------
     slot
    (1 row)

And of course the second node runs the logical receiver receiver\_raw.

Both nodes use the same schema, a simple table with a primary key:

    $ psql -c '\d aa' postgres
          Table "public.aa"
     Column |  Type   | Modifiers 
    --------+---------+-----------
     a      | integer | not null
    Indexes:
        "aa_pkey" PRIMARY KEY, btree (a)

Using the whole set, do the changes get replicated? Obviously the
answer is yes or this post has no meaning, here are some tuples inserted
on node 1...

    $ psql -c 'INSERT INTO aa VALUES (generate_series(1,10))' postgres
    INSERT 0 10

... Getting replicated on node 2...

    $ psql -p 5433 -c 'SELECT count(*) FROM aa' postgres
     count 
    -------
        10
    (1 row)

Feel free to test the two plugins used in this example for your own
needs. A direct application of those things would be to create a
set of nodes replicating changes in circle, the only challenge being
to be sure to track what is the node from which the change comes from
at then to stop applying the change once it comes back to its origin.
This would need some kind of node origin tracker. Constraint validation
is of course another story...

Note that this is the last post dedicated to the introduction of logical
replication for 9.4, feel free to refer to the previous entries of the
series as well:

  * [More about replication slots]
(/postgresql-2/postgres-9-4-feature-highlight-replication-slots/)
  * [Basics about logical replication]
(/postgresql-2/postgres-9-4-feature-highlight-basics-logical-decoding/)
  * [REPLICA IDENTITY]
(/postgresql-2/postgres-9-4-feature-highlight-replica-identity-logical-replication/)
  * [About logical decoding plugins]
(/postgresql-2/postgres-9-4-feature-highlight-output-plugin-logical-replication/)
  * [Logical replication protocol]
(/postgresql-2/postgres-9-4-feature-highlight-logical-replication-protocol/)

The documentation of Postgres itself about [logical decoding]
(https://www.postgresql.org/docs/devel/static/logicaldecoding.html) is of
course highly recommended.
