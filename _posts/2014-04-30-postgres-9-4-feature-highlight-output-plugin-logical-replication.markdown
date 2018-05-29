---
author: Michael Paquier
lastmod: 2014-04-30
date: 2014-04-30 13:15:43+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-output-plugin-logical-replication
title: 'Postgres 9.4 feature highlight - Creating an output plugin for logical replication'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.4
- logical
- replication
- plugin

---
Continuing on the series of posts about logical replication and after
looking at [some basics]
(/postgresql-2/postgres-9-4-feature-highlight-basics-logical-decoding/)
and the concept of [REPLICA IDENTITY]
(/postgresql-2/postgres-9-4-feature-highlight-replica-identity-logical-replication/)
for a table, now is time to begin more serious things by having a look
at how to develop an output plugin for the logical decoding facility.

Do you remember? Logical decoding is made of roughly two major parts:

  * A decoder generating the database changes, that reads and translate
WAL files into a format given by a custom plugin that can be defined when
a logical replication slot is created. An example of that in core is the
contribution module called [test_decoding]
(https://www.postgresql.org/docs/devel/static/test-decoding.html). This is
linked with a replication slot.
  * A receiver, that can consume the changes decoder has created.
[pg_recvlogical]
(https://www.postgresql.org/docs/devel/static/app-pgrecvlogical.html)
as well as the SQL functions pg\_logical\_slot\_[get|peek]\_changes
as good examples of that.

In short, in PostgreSQL architecture a logical decoder is a set of callback
functions that are loaded from a library listed in shared\_preload\_libraries
when server starts. Those callbacks functions need to be defined through
a function called \_PG\_output\_plugin\_init and here is their list:

  * startup\_cb, called when a replication slot is created or when changes
are requested. Put in here things like dedicated memory contexts or option
management for example.
  * shutdown\_cb, called when a replication slot is not used anymore. You
should do here the necessary clean-up actions for things created at startup
phase.
  * begin_cb and commit_cb, called when respectively a transaction BEGIN or
COMMIT has been decoded. Transaction context is available here so you use
this data in the decoding stream as well.
  * change_cb, called when a change on database has occurred. By far this
is the most important one to be aware of in my opinion. With this callback
is available information about the relation changed in the shape of a Relation
entry and data: the old and new tuple as some HeapTupleData and
HeapTupleHeaderData entries.

The role of the decoder plugin is to use all the data available and put it
in a shape that will be useful for a receiver when it is streamed. Its
flexibility is actually what makes this facility really powerful and useful
already for many things like rolling upgrades, audit functions, replication,
etc.

Note as well that a decoder can also use \_PG\_init to perform initialization
actions when it is loaded. By the way, when looking at implementing your
own decoder, the best advice givable is to base your implementation on
the existing plugin in PostgreSQL core called test\_decoding. This module
does not do much in itself, but it is a gold mine for beginners and will save
you hours and a lot of tears. It is however preferable to have some knowledge
of the APIs of PostgreSQL before jumping in the wild. And this is actually
what I did to implement my own decoder, called [decoder\_raw]
(https://github.com/michaelpq/pg_plugins/tree/master/decoder_raw) available
in a personal repository on github called [pg_plugins]
(https://github.com/michaelpq/pg_plugins) (that's actually the repository
I used to create a set of templates for backgroud workers when studying them).
This plugin is able to decode WAL entries and generate raw SQL queries that
stream receivers can use as-is. The code is a bit longer than test\_decoding
as there is some logic in the WHERE clause of UPDATE and DELETE queries
caused by the logic of REPLICA IDENTITY for the DEFAULT and INDEX cases
to enforce tuple selectivity on a table's primary key (DEFAULT case) or a
not null unique index (INDEX case).

Here is for example how the callback functions are defined:

    void
    _PG_output_plugin_init(OutputPluginCallbacks *cb)
    {
        AssertVariableIsOfType(&_PG_output_plugin_init, LogicalOutputPluginInit);

        cb->startup_cb = decoder_raw_startup;
        cb->begin_cb = decoder_raw_begin_txn;
        cb->change_cb = decoder_raw_change;
        cb->commit_cb = decoder_raw_commit_txn;
        cb->shutdown_cb = decoder_raw_shutdown;
    }

Then, without entering in the details, here a couple of things that you need
to be aware of even if implementation is based on the structure of
test\_decoding.

First, the relation information in structure Relation contains a new OID field
called rd_replidindex that defines the OID if the REPLICA IDENTITY index if
it exists. This is either a PRIMARY KEY or a user-defined index. Use and
abuse of it! It is really helpful. A common usage of rd_replidindex is to
open an index relation on it and then scan indnatts to find the list of
column attributes the index refers to. Useful to define a list of keys
that can uniquely define a tuple on a remote source for an UPDATE or DELETE
change. Here is a way to do that:

    int key;
    Relation indexRel = index_open(relation->rd_replidindex, ShareLock);

    for (key = 0; key < indexRel->rd_index->indnatts; key++)
    {
        int relattr = indexRel->rd_index->indkey.values[key - 1];
        /*
         * Perform an action with the attribute number of parent relation
         * and tuple data.
         */
        do_action_using_attribute_number(relattr, tupledata);
    }
    index_close(indexRel, NoLock);

Then, use a common way to generate the relation name for all the change
types (INSERT, UPDATE, DELETE). Something like that will generate
a complete relation name with both namespace and table name:

    Relation rel = blabla;
    Form_pg_class   class_form = RelationGetForm(rel);

    appendStringInfoString(s,
	quote_qualified_identifier(
                get_namespace_name(
                           get_rel_namespace(RelationGetRelid(rel))),
            NameStr(class_form->relname)));

Now let's see how this works, with for example the following SQL sequence:

    =# -- Create slot
    =# SELECT slot_name
       FROM pg_create_logical_replication_slot('custom_slot', 'decoder_raw');
      slot_name
    --------------
     custom_slot
    (1 row)
    =# -- A table using DEFAULT as REPLICA IDENTITY and some operations
    =# CREATE TABLE aa (a int primary key, b text);
    CREATE TABLE
    =# INSERT INTO aa VALUES (1, 'aa'), (2, 'bb');
    INSERT 0 2
    =# UPDATE aa SET b = 'cc' WHERE a = 1;
    UPDATE 1
    =# DELETE FROM aa WHERE a = 1;
    DELETE 1

And the following output is generated by the plugin.

    =# SELECT data
       FROM pg_logical_slot_peek_changes('custom_slot',
                 NULL, NULL, 'include-transaction', 'on');
                            data
    ----------------------------------------------------
     BEGIN;
     COMMIT;
     BEGIN;
     INSERT INTO public.aa (a, b) VALUES (1, 'aa');
     INSERT INTO public.aa (a, b) VALUES (2, 'bb');
     COMMIT;
     BEGIN;
     UPDATE public.aa SET a = 1, b = 'cc' WHERE a = 1 ;
     COMMIT;
     BEGIN;
     DELETE FROM public.aa WHERE a = 1 ;
     COMMIT;
    (12 rows)

Pretty handy, no? Note that the rows of UPDATE and DELETE queries are
identified using the primary key of relation.

Consuming such changes shapped like that is straight-forward: simply
use them on another PostgreSQL node that has schema and data consistent
with the node decoding the changes before replication slot was marked
as active. Here is for example a command using pg\_logical\_slot\_get\_changes
running periodically that is able to replicate all the changes on an other
node listening to port 5433:

    psql -At -c "SELECT pg_logical_slot_get_changes('custom_slot', NULL, NULL)" | \
        psql -p 5433

This way, the second node replicates all the changes occuring on first node
doing the decoding effort. The code of decoder_raw has been released under
the PostgreSQL license and is available [here]
(https://github.com/michaelpq/pg_plugins/tree/master/decoder_raw). Feel
free to use it, feedback is welcome as well.
