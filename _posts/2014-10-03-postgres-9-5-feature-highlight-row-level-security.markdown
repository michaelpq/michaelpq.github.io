---
author: Michael Paquier
lastmod: 2014-10-03
date: 2014-10-03 14:20:36+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-row-level-security
title: 'Postgres 9.5 feature highlight - Row-Level Security and Policies'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.5
- security

---

[Row-level security](http://www.postgresql.org/docs/devel/static/ddl-rowsecurity.html) is
a new feature of PostgreSQL 9.5 that has been introduced by this commit:

    commit: 491c029dbc4206779cf659aa0ff986af7831d2ff
    author: Stephen Frost <sfrost@snowman.net>
    date: Fri, 19 Sep 2014 11:18:35 -0400
    Row-Level Security Policies (RLS)

    Building on the updatable security-barrier views work, add the
    ability to define policies on tables to limit the set of rows
    which are returned from a query and which are allowed to be added
    to a table.  Expressions defined by the policy for filtering are
    added to the security barrier quals of the query, while expressions
    defined to check records being added to a table are added to the
    with-check options of the query.

Behind this jargon is a feature that could be defined in short words as
a complementary permission manager of [GRANT](http://www.postgresql.org/docs/devel/static/sql-grant.html) and
[REVOKE](http://www.postgresql.org/docs/devel/static/sql-revoke.html)
that allows controlling at row level which tuples can be retrieved
for a read query or manipulated using INSERT, UPDATE or DELETE.
This row control mechanism is controlled using a new query called
[CREATE POLICY](http://www.postgresql.org/docs/devel/static/sql-createpolicy.html)
(of course its flavor [ALTER POLICY](http://www.postgresql.org/docs/devel/static/sql-alterpolicy.html)
to update an existing policy and [DROP POLICY](http://www.postgresql.org/docs/devel/static/sql-droppolicy.html)
to remove a policy exist as well). By default, tables have no
restrictions in terms of how rows can be added and manipulated.
However they can be made able to accept level restriction policies
using [ALTER TABLE](http://www.postgresql.org/docs/devel/static/sql-altertable.html)
and ENABLE ROW LEVEL SECURITY. Now, let's imagine the following table
where a list of employees and their respective salaries can be read
(salary is an integer as this is entirely fictive situation and refers
to no real situation, quoique...):

    =# CREATE TABLE employee_data (id int,
           employee text,
           salary int,
           phone_number text);
    CREATE TABLE
    =# CREATE ROLE ceo;
    CREATE ROLE
    =# CREATE ROLE jeanne;
    CREATE ROLE
    =# CREATE ROLE bob;
    CREATE ROLE
    =# INSERT INTO employee_data VALUES (1, 'ceo', 300000, '080-7777-8888');
    INSERT 0 1
    =# INSERT INTO employee_data VALUES (2, 'jeanne', 1000, '090-1111-2222');
    INSERT 0 1
    =# INSERT INTO employee_data VALUES (3, 'bob', 30000, '090-2222-3333');
    INSERT 0 1

Now let's set some global permissions on this relation using GRANT.
Logically, the CEO has a complete control (?!) on the grid of salary of
his employees.

    =# GRANT SELECT, INSERT, UPDATE, DELETE ON employee_data TO ceo;
    GRANT

A normal employee can have information access to all the information, and
can update as well his/her phone number or even his/her name:

    =# GRANT SELECT (id, employee, phone_number, salary)
       ON employee_data TO public;
    GRANT
    =# GRANT UPDATE (employee, phone_number) ON employee_data TO public;
    GRANT

As things stand now though, everybody is able to manipulate other's
private data and not only his own. For example Jeanne can update her
CEO's name:

    =# SET ROLE jeanne;
    SET
    => UPDATE employee_data
       SET employee = 'Raise our salaries -- Signed: Jeanne'
       WHERE employee = 'CEO';
    UPDATE 1

Row-level security can be used to control with more granularity what
are the rows that can be manipulated for a set of circumstances that
are defined with a policy. First RLS must be enabled on the given table:

    =# ALTER TABLE employee_data ENABLE ROW LEVEL SECURITY;
    ALTER TABLE

Note that if there are no policies defined and that RLS is enabled
normal users that even have GRANT access to a certain set of operations
can do nothing:

    => set role ceo;
    SET
    => UPDATE employee_data SET employee = 'I am God' WHERE id = 1;
    UPDATE 0

So it is absolutely mandatory to set policies to bring the level of
control wanted for a relation if RLS is in the game. First a policy
needs to be defined to let the CEO have a complete access on the
table (the default being FOR ALL all the operations are authorized
this way to the CEO), and luckily Jeanne just got a promotion:

    =# CREATE POLICY ceo_policy ON employee_data TO ceo
       USING (true) WITH CHECK (true);
    CREATE POLICY
    =# SET ROLE ceo;
    SET
    => UPDATE employee_data SET salary = 5000 WHERE employee = 'jeanne' ;
    UPDATE 1
    => SELECT * FROM employee_data ORDER BY id;
     id | employee | salary | phone_number
    ----+----------+--------+---------------
      1 | ceo      | 300000 | 080-7777-8888
      2 | jeanne   |   5000 | 090-1111-2222
      3 | bob      |  30000 | 090-2222-3333
    (3 rows)

Even with SELECT access allowed through GRANT, Bob and Jeanne cannot
view any row so they cannot view even their own information. This can
be solved with a new policy (note in this case the clause USING that
can be be used to define a boolean expression on which the rows are
filtered):

    =# CREATE POLICY read_own_data ON employee_data
       FOR SELECT USING (current_user = employee);
    CREATE POLICY
    =# SET ROLE jeanne;
    SET
    => SELECT * FROM employee_data;
     id | employee | salary | phone_number
    ----+----------+--------+---------------
      2 | jeanne   |   5000 | 090-1111-2222
    (1 row)

A user should be able to modify his own information as well, and note
now the WITH CHECK clause that can be used to check the validity of
a row once it has been manipulated. In this case, the employee name
cannot be updated to a value other than the role name (well it was
better not to give UPDATE access with GRANT to this column but this
would have made an example above invalid...), and the new phone number
cannot be NULL (have you though that the ceo can actually set his phone
number to NULL, something less flexible with CHECK at relation level):

    =# CREATE POLICY modify_own_data ON employee_data
	   FOR UPDATE USING (current_user = employee)
	   WITH CHECK (employee = current_user AND phone_number IS NOT NULL);
    CREATE POLICY
    =# SET ROLE jeanne;
    SET
    => UDATE employee_data SET id = 10; -- blocked by GRANT
    ERROR:  42501: permission denied for relation employee_data
    LOCATION:  aclcheck_error, aclchk.c:3371
    => UPDATE employee_data SET phone_number = NULL; -- blocked by policy 
    ERROR:  44000: new row violates WITH CHECK OPTION for "employee_data"
    DETAIL:  Failing row contains (2, jeanne, 5000, null).
    LOCATION:  ExecWithCheckOptions, execMain.c:1684
    => UPDATE employee_data SET phone_number = '1-1000-2000'; -- OK
    UPDATE 1

Using this new policy, Jeanne has updated her phone number, and the CEO
can check that freely:

    => SET ROLE ceo;
    SET
    => SELECT * FROM employee_data ORDER BY id;
     id | employee | salary | phone_number
    ----+----------+--------+---------------
      1 | ceo      | 300000 | 080-7777-8888
      2 | jeanne   |   5000 | 1-1000-2000
      3 | bob      |  30000 | 090-2222-3333
    (3 rows)

So, while GRANT and REVOKE offer control of the actions that can be done
on a relation for a set of users vertically (control of columns), RLS
offers the possibility to control things horizontally for each record
so when using this feature be sure to use both together and wisely.
