---
author: Michael Paquier
comments: true
date: 2011-09-18 11:02:39+00:00
layout: post
slug: reduce-cost-of-select-count-queries-with-trigger-based-method
title: Reduce cost of select count(*) queries with trigger-based method
wordpress_id: 512
categories:
- PostgreSQL-2
tags:
- consumption
- cost
- count
- cpu
- memory
- postgres
- postgresql
- query
- reduce
- resource
- table scan
- trigger
---

Scanning a table in a database can cost a lot in terms of CPU or I/O when calculating statistics in an application. The bigger application tables get, the more resource is necessary to calculate simple statistics for an application.
A simple example of that are queries of the type:

    SELECT count(*) FROM table;

This query is resource-consuming for two reasons:

  1. It does not use any WHERE clause which interact with a primary key of a table or on a column index that could accelerate query with b-tree search.
  2. It has to scan completely a table to determine a simple count result, in this case the total number of tuples in the table.



Such simple queries that lazy programmers (like me) use all the time can be really a pain for a system if it has to be done on a table with billions of tuples. Scanning all the table can be however avoided by using an external trigger-based method in PostgreSQL. Just to recall, a trigger is a SQL functionality that allows to fire special actions on a table if a certain kind of action is perform on its tuples (INSERT, DELETE, UPDATE).

The idea here is to count the number of tuples inserted and deleted on a table and to count each action done through simple incrementation (for INSERT) and decrementation (for DELETE).

Let's first create 2 tables.

    CREATE TABLE my_table (a int);
    CREATE TABLE table_cnt (table_oid Oid PRIMARY KEY, count int);

my_table is a generic table whose tuples will be counted with triggers on it. table_cnt counts the number of tuples in the application tables. It contains 2 columns, one based on the table Oid whose tuples are counted and an integer which is used to determine the total number of tuples in this table. A primary key is defined on the table Oid (object ID)... Well as we are sure that a table Oid is unique in a PostgreSQL instance, this does not really matter but may avoid future conflicts in the system.

In order to count the number of tuples in a given table, two functions in charge of count management are created, one for incrementation and one for decrementation.

    CREATE FUNCTION count_increment() RETURNS TRIGGER AS $_$
    BEGIN
    UPDATE table_cnt SET count = count + 1 WHERE table_oid = TG_RELID;
    RETURN NEW;
    END $_$ LANGUAGE 'plpgsql';
    CREATE FUNCTION count_decrement() RETURNS TRIGGER AS $_$
    BEGIN
    UPDATE table_cnt SET count = count - 1  WHERE table_oid = TG_RELID;
    RETURN NEW;
    END $_$ LANGUAGE 'plpgsql';

Those two functions will be called by the table triggers. One important point to notice is the use of the variable called TG_RELID, which is the relation ID of the table that invocated this function with its trigger. PostgreSQL contains other variables related to PL/PGSQL functions like the type of action involved, etc. Please refer to PostgreSQL manuals for more details.

Then it is time to create the triggers on the table.

    CREATE TRIGGER mytable_increment_trig AFTER INSERT ON my_table FOR EACH ROW EXECUTE PROCEDURE count_increment();
    CREATE TRIGGER mytable_decrement_trig AFTER DELETE ON my_table FOR EACH ROW EXECUTE PROCEDURE count_decrement();

Here the fire is trigger each time a row is inserted or deleted to maintain a consistent count, with the usage of clause FOR EACH ROW. Count incrementation is done for an INSERT action and decrementation is done with a DELETE action. The key-point here is the usage of the clause AFTER, meaning that trigger is fire "AFTER" the DML action is done on table, insuring that count is not updated if an error occured at data insertion or deletion.

When creating the tables and everything, also do not forget to initialize the count itself.

    INSERT INTO table_cnt VALUES ('my_table'::regclass, 0);

'my_table'::regclass permits to use the table Oid instead of a plain table name string.

Once all the system is in place, all you need to do to obtain the total number of tuples on a table is to use:

    SELECT count FROM table_cnt where table_oid = 'my_table'::regclass;

So now let's see what you simply get as results by comparing normal count query and the optimized method.

    template1=# INSERT INTO my_table VALUES (generate_series(1,10000));
    INSERT 0 10000

This populated the table with 10,000 tuples. This population takes more time than normal because the trigger stuff is in action, normal applications rarely insert 10,000 in a row except if it is a benchmark of course.

Let's check how runs the normal count method.

    template1=# SELECT count(*) FROM my_table;
     count 
    -------
     10000
    (1 row)
    template1=# EXPLAIN ANALYZE SELECT count(*) FROM my_table;
                                                         QUERY PLAN                                                      
    ---------------------------------------------------------------------------------------------------------------------
    Aggregate  (cost=4478.00..4478.01 rows=1 width=0) (actual time=102.265..102.267 rows=1 loops=1)
       ->  Seq Scan on my_table  (cost=0.00..4453.00 rows=10000 width=0) (actual time=45.437..75.138 rows=10000 loops=1)
     Total runtime: 102.440 ms
    (3 rows)

Query has been run in 100ms. Well, 10,000 tuples have been scanned so that's expected.

And with the optimized method.

    template1=# SELECT count FROM table_cnt where table_oid = 'my_table'::regclass;
     count 
    -------
     10000
    (1 row)
    template1=# EXPLAIN ANALYZE SELECT count FROM table_cnt where table_oid = 'my_table'::regclass;
                                                QUERY PLAN                                             
    ---------------------------------------------------------------------------------------------------
     Seq Scan on table_cnt  (cost=0.00..7.01 rows=1 width=4) (actual time=0.061..0.065 rows=1 loops=1)
       Filter: (table_oid = 21815::oid)
     Total runtime: 0.148 ms
    (3 rows)

Query needs 1000 less time to run, you just get a result directly from a table. If your table has billions of rows, you can imagine the execution time difference is even greater.

Just a note about the results, all the queries have been run in a non-tuned server. The important point here was the comparison of time to run each method so system characteristics do not really matter.

Here is a remark about data generation with generate_series. It is dangerous to use generate_series on a table using triggers as it really heavies the whole insertion process. But once again, this was just use to check the optimized count-method with triggers.
Here is how the generation time changes.
1) On a table with triggers fired on it.

    template1=# explain analyze insert into my_table values (generate_series (1,10000));
                                              QUERY PLAN                                           
    -----------------------------------------------------------------------------------------------
     Insert  (cost=0.00..0.01 rows=1 width=0) (actual time=346.833..346.833 rows=0 loops=1)
       ->  Result  (cost=0.00..0.01 rows=1 width=0) (actual time=0.026..41.406 rows=10000 loops=1)
     Trigger mytable_increment_trig: time=7192.252 calls=10000
     Total runtime: 7572.754 ms
    (4 rows)

Trigger call uses most of the ressources.

2) On the same table without triggers fired.
    template1=# explain analyze insert into my_table values (generate_series (1,10000));
                                              QUERY PLAN                                           
    -----------------------------------------------------------------------------------------------
     Insert  (cost=0.00..0.01 rows=1 width=0) (actual time=170.892..170.892 rows=0 loops=1)
       ->  Result  (cost=0.00..0.01 rows=1 width=0) (actual time=0.026..34.692 rows=10000 loops=1)
     Total runtime: 171.018 ms
    (3 rows)

Indeed, this takes less time... So son't forget to use this method wisely.
