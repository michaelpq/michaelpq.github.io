---
author: Michael Paquier
lastmod: 2012-03-13
date: 2012-03-13 06:03:02+00:00
layout: post
type: post
slug: triggers-in-a-cluster-database
title: Triggers in a cluster database
categories:
- PostgreSQL-2
tags:
- cluster
- database
- design
- event
- pgxc
- postgres
- postgres-xc
- postgresql
- though
- trigger
---

Here are some thoughts about trigger events in a database cluster environment, those design thoughts are particularly related to Postgres-XC, scaling-out database cluster based on PostgreSQL.

In PostgreSQL, triggers have the following format:

    CREATE [ CONSTRAINT ] TRIGGER name { BEFORE | AFTER | INSTEAD OF } { event [ OR ... ] }
    ON table
    [ FROM referenced_table_name ]
    { NOT DEFERRABLE | [ DEFERRABLE ] { INITIALLY IMMEDIATE | INITIALLY DEFERRED } }
    [ FOR [ EACH ] { ROW | STATEMENT } ]
    [ WHEN ( condition ) ]
    EXECUTE PROCEDURE function_name ( arguments )

A trigger event can be fired with the following events.

    INSERT
    UPDATE [ OF column_name [, ... ] ]
    DELETE
    TRUNCATE

OK, up to now nothing is new and it is plainly what you can find in [PostgreSQL documentation](http://www.postgresql.org/docs/9.1/static/sql-createtrigger.html).

However, let's do a short explanation of what are triggers in a database (really basic). A trigger is the possibility to perform automatic action after a special event in a database. Triggers are usually used to make some checks on constraints in database, to do some additional operations on tables like statistics for an application independent on PostgreSQL system. In a Web environment, a direct application of trigger is the possibility to fire for example an email after a certain event occurred on the database. There are a lot of applications around that. So roughly, a trigger is fired after a certain event, which is data modification on database.

PostgreSQL provides a good granularity when defining the conditions of a trigger firing. All the following elements constitute an event that could fire a trigger.
	
  * Table on which the SQL operation is done.	
  * Type of SQL operation happening on table, basically a DML (INSERT, UPDATE, DELETE) or a TRUNCATE.
  * Boolean condition determining if the trigger will be fired (WHEN, INSTEAD OF). It can be a condition on the old and new values during the DML operation. In this case you cannot use old values with an INSERT and new values with a DELETE.	
  * Transaction commit time (DEFERRABLE). A trigger firing can be deferred at a transaction commit or at the statement time.
  * Statement or tuple-based firing. In the case of a statement-based firing, trigger is fired with each query. For a tuple-based trigger, this trigger is fired each time a tuple of the table is modified. Let's imagine that you have a system with a trigger that is fired when a tuple from a table A is deleted. If you delete 1,000,000 tuples in this table A, this trigger will be fired 1,000,000 times. Here it would be pretty costly.
  * After or before the data is being modified (AFTER/BEFORE).

Once a trigger is fired, it launches a procedure that may interact with the data modified by the awakening action. It is usually a plpgsql function. Well, as it can be a very costly operation, take care when you design your client application running on top of the database.

Now, let's move to the root of the problem, which is the goal of this post. What are the conditions under which we should manage triggers in a clustering environment? By a clustering environment, I mean a database cluster where you have a client application connecting to one node of this cluster, but it needs to interact with remote nodes. In this case, the main point is to determine if a trigger can be fired on local node, the node where the application is connected to, or on remote node, the node where the database modification happens (and you may also have data modification happening on local node, why not?!). So, we need to determine under which conditions a trigger is shippable to a remote node or not.
Without suspense, here are the two conditions that I suppose are necessary and sufficient (other ideas are welcome) to determine if a trigger is shippable or not in a database cluster.

  1. The shippability of the procedure fired by trigger
  2. The shippability of the query used by application, the one modifying database and firing the trigger event

In PostgreSQL, a procedure is shippable if it is immutable, meaning that it does not modify the content of the database if launched. A query is shippable if it does not contain expressions that are not shippable.
Here are some simple examples of shippable queries:

    SELECT * from aa WHERE a = 1;
    INSERT INTO aa VALUES (1),(2);

Non-shippable queries:

    SELECT * FROM aa WHERE a = nextval('seq');
    INSERT INTO aa VALUES (currval('seq'), nextval('seq'));

Please note that query shippability depends also on a bunch of other conditions like join conditions and distribution types of the tables with which is for example interacting the query. For example by doing a join on two tables whose data are on different nodes, we need to fetch the data from remote node to local node, then perform the join on local node. There are a lot of cases to consider depending on the way your database clustering application distributes data among the cluster (column, sharding, etc.).
The choice of those 2 conditions is simply made by analyzing which part of the trigger firing conditions may contain elements that are clustering-dependent. In this case query conditioning the firing and the procedure fired by trigger are the only two conditions that need to be checked.

Those two conditions lead to 4 cases to determine where a trigger can be fired.

  * If query is shippable and procedure is shippable, trigger is fired on remote node.	
  * If query is not shippable and procedure is shippable, trigger is fired on local node.
  * If query is shippable and procedure is not shippable, trigger is fired on local node.
  * If query is not shippable and procedure is not shippable, trigger is fired on local node.

This analysis has been a part of some design work for Postgres-XC in order to support triggers fully in a database cluster.
Once again, those are only thoughts, and any opinion is welcome. So feel free to comment.
