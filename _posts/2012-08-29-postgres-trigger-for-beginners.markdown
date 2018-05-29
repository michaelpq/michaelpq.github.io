---
author: Michael Paquier
lastmod: 2012-08-29
date: 2012-08-29 03:18:45+00:00
layout: post
type: post
slug: postgres-trigger-for-beginners
title: 'Postgres: TRIGGER for beginners'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- trigger

---

This post has as goal to provide basics to help you understanding how work triggers in PostgreSQL.
A [trigger](https://www.postgresql.org/docs/9.1/static/sql-createtrigger.html) is the possibility to associate an automatic operation to a table in case a write event happens on this given table.

Here is the synopsis of this query.

    CREATE [ CONSTRAINT ] TRIGGER name { BEFORE | AFTER | INSTEAD OF } { **event** [ OR ... ] }
    ON **table**
    [ FROM referenced_table_name ]
    { NOT DEFERRABLE | [ DEFERRABLE ] { INITIALLY IMMEDIATE | INITIALLY DEFERRED } }
    [ FOR [ EACH ] { ROW | STATEMENT } ]
    [ WHEN ( condition ) ]
    **EXECUTE PROCEDURE function_name ( arguments )**

The parts that are essential to get the basics are written in strong characters.

  * **event**, this is the database operation that will cause the trigger to fire. In Postgres 9.2 and prior versions, this can occur for INSERT, UPDATE, DELETE and TRUNCATE	
  * **table**, this is the database table where the event has to occur
  * **EXECUTE PROCEDURE function\_name ( arguments )**, this is the operation that is launched by trigger after being fired. The procedure can be customized with data related to the table or other things depending on the circumstances trigger is fired. Have a look [here](https://www.postgresql.org/docs/9.1/static/plpgsql-trigger.html) for more details about trigger procedures.

Triggers have many usages. Defined on the given table of your database, you can set up a trigger to launch automatic operations on a table each time an event is done on it. Once fired, this trigger will execute an automatic procedure that will perform a list of operations predefined by user. So this limits the amount of code you need to write on the application side, limiting the possibility of bugs in your own code while using Postgres server robustness.

But let's take a simple example: an address book.
Let's imagine that you are managing your address book with Postgres. Really for simplicity's sake, your system manages only the names and addresses of people you know.
The people you know have a unique name, but they can have multiple addresses, as you might register their main home address and work address for example. So, your system will have the following basic schema:

    CREATE TABLE users (id int PRIMARY KEY, name varchar(256));
    CREATE TABLE address (id_user int, address text);

Let's suppose that you are a lucky guy and that you know where I live and where is my workplace (some of this data is perhaps wrong).

    postgres=# INSERT INTO users VALUES (1, 'Michael P');
    INSERT 0 1
    postgres=# INSERT INTO address VALUES (1, 'Work in Tokyo, Japan');
    INSERT 0 1
    postgres=# INSERT INTO address VALUES (1, 'Live in San Francisco, California');
    INSERT 0 1

Then you can recover my addresses easily.

    postgres=# SELECT address FROM users JOIN address
    postgres=# ON (users.id = address.id_user) WHERE name = 'Michael P';
                  address              
    -----------------------------------
     Work in Tokyo, Japan
     Live in San Francisco, California
    (2 rows)

However it happens that you are not caring anymore about me and that you wish to delete my data from your address book. Intuitively, deleting an entry from an address book is simply removing the wanted name. But, if you do that the address data will remain. Of course you can let your application manage the deletion for both tables "users" and "address", but you will need to send 2 SQL queries. This is a waste of resource as you need to go twice to your database to perform the complete deletion. In this case at least it is.

Triggers can allow you to simplify the deletion operation by automatizing the data deletion on table "addresses" if a user is deleted from your address book. You need to create the following objects in order to do that.

    CREATE FUNCTION delete_address() RETURNS TRIGGER AS $_$
    BEGIN
        DELETE FROM address WHERE address.id_user = OLD.id;
        RETURN OLD;
    END $_$ LANGUAGE 'plpgsql';

This function is set to delete the addresses for a given user ID.
Then create the trigger event. What is necessary here is to launch the previous function each time an entry is removed from table "users", explaining the clause "FOR EACH ROW". The address clean up is also done before the actual DELETE happens on table "users".

    CREATE TRIGGER delete_user_address BEFORE DELETE ON users FOR EACH ROW EXECUTE PROCEDURE delete_address();

Let's test the entry deletion.

    postgres=# DELETE FROM users WHERE name = 'Michael P';
    DELETE 1
    postgres=# select * from address;
     id_user | address 
    ---------+---------
    (0 rows)

And my address data has completely disappeared from your database thanks to the trigger.
Have fun with this feature.
