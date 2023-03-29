---
author: Michael Paquier
lastmod: 2023-03-29
date: 2023-03-29 03:35:15+00:00
layout: post
type: post
slug: postgres-16-hba-ident-include
title: 'Postgres 16 highlight - File inclusions in pg_hba.conf and pg_ident.conf'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 16
- administration
- configure

---

The third and last phase of the improvements done in PostgreSQL 16 for
authentication configuration involves both
[pg\_hba.conf](https://www.postgresql.org/docs/devel/auth-pg-hba-conf.html)
and [pg\_ident.conf](https://www.postgresql.org/docs/devel/auth-username-maps.html),
mainly with this
[commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=a54b658):

    commit: a54b658ce77b6705eb1f997b416c2e820a77946c
    author: Michael Paquier <michael@paquier.xyz>
    date: Thu, 24 Nov 2022 13:51:34 +0900
    Add support for file inclusions in HBA and ident configuration files

    pg_hba.conf and pg_ident.conf gain support for three record keywords:
    - "include", to include a file.
    - "include_if_exists", to include a file, ignoring it if missing.
    - "include_dir", to include a directory of files.  These are classified
    by name (C locale, mostly) and need to be prefixed by ".conf", hence
    following the same rules as GUCs.

    [ ... ]

    Author: Julien Rouhaud
    Reviewed-by: Michael Paquier
    Discussion: https://postgr.es/m/20220223045959.35ipdsvbxcstrhya@jrouhaud

This feature is at the core of making pg\_hba.conf and pg\_ident.conf more
in-line with postgresql.conf, even if the parsing logic of the first two is
not the same as the third one as GUCs require their own thing, while HBA and
ident files need to handle full entries made of a sequence of items.  And
some of these items can be lists, additionally.

Up to PostgreSQL 15, inclusion of files is possible in pg\_hba.conf within a
list for databases and users, by defining a file path prefixed by '@'.  This
can be a relative path, compiled from the location of the HBA file being
currently read, or even absolute.  Note that a file *has* to exist, and not
finding one in the path defined results in a loading failure.  For example,
here is a set of two files loaded by hba.c:

    $ cat $PGDATA/pg_hba.conf
    # TYPE  DATABASE                USER     ADDRESS   METHOD
    local   db_1,@dblist.conf,db_2  user_1             trust
    $ cat $PGDATA/dblist.conf
    db_3,db_4
    db_5 db_6
    db_7

The tokenization of the second file is very flexible, following a few rules:

  * Comma-separated items listed on the same line are treated as a full list
  of multiple elements.
  * Items separated by whitespaces and newlines are separate elements.

Hence, using the previous example,
[pg\_hba\_file\_rules](https://www.postgresql.org/docs/devel/view-pg-hba-file-rules.html)
reports this data, with seven databases listed (note the order of the items):

    =# select type, database, user_name from pg_hba_file_rules;
     type  |               database               | user_name
    -------+--------------------------------------+-----------
     local | {db_1,db_3,db_4,db_5,db_6,db_7,db_2} | {user_1}
    (1 row)

Speaking of which, attempting a circling dependency with these files would
cause a failure at reload.  For example, see this file including itself:

    $ cat $PGDATA/pg_hba.conf
    # TYPE  DATABASE      USER     ADDRESS   METHOD
    local   @pg_hba.conf  user_1             trust

The error generated is..  Surprising up to PostgreSQL 15 and older versions,
and this has never been reported to the lists as far as I know:

    FATAL:  exceeded maxAllocatedDescs (166) while trying to open file "/to/data/folder/pg_hba.conf"

In 16 and newer versions, things are improved a lot, with the same
rules applied as for postgresql.conf, with a context line produced for
each file read across the included chain.  This way, it is possible to get
a full log of the events leading down to the location of the error, (here
the context leads to 10 times the same line as the file includes itself,
respecting the depth limit of included files):

    LOG:  listening on Unix socket "/socket/path/.s.PGSQL.5432"
    LOG:  could not open file "/to/data/folder/pg_hba.conf": maximum nesting depth exceeded
    CONTEXT:  line 2 of configuration file "/to/data/foler/pg_hba.conf"
      [ ... ]
      line 2 of configuration file "/to/data/folder/pg_hba.conf"

Now, back to the actual feature...  The commit message mentioned above
explains it all, with one argument on the thread discussing this feature
that it can be useful in container configurations.  This consists of three
new clauses available in
[HBA](https://www.postgresql.org/docs/devel/auth-pg-hba-conf.html)
and [ident files](https://www.postgresql.org/docs/devel/auth-username-maps.html).
Each file included must be written with rules or maps compatible with the
format of HBA or ident files.  Here is a more advanced example for HBA rules,
one record is incorrect (which one?), leading to a reload failure:

    $ cat $PGDATA/pg_hba.conf
    include_if_exists pg_hba_extra.conf
	include_dir hba_conf
    $ cat $PGDATA/hba_conf/001_hba.conf
    # TYPE  DATABASE  USER     ADDRESS   METHOD
    local   db_1      user_1             trust
    $ cat $PGDATA/hba_conf/002_hba.conf
    # TYPE  DATABASE  USER     ADDRESS   METHOD
    local   db_0      user_0             trust
    local   db_2      user_2             incorrect
    $ cat $PGDATA/pg_hba_extra.conf
    # TYPE  DATABASE  USER     ADDRESS   METHOD
    local   db_3      user_3             trust

There are a few gotchas to be aware of.

First, the order of the files listed in a directory is strictly decided:
these are ordered by name, after scanning the directory to get a full list
of them.  One thing I would recommend to do is adding numbers in front of
their names, for example, to guarantee a strict order.  An empty folder,
or a directory made of files with no contents, leads to the same effect
as an empty pg\_hba.conf: if at the end of loading the whole no entries
are found, the reload fails.  A missing directory defined by
"include\_dir" causes a hard failure, and a directory having zero files
suffixed by ".conf" is a valid flow.

"include" and "include\_if\_exists" differ in the error handling, with
semantics similar to postgresql.conf.  If a file listed by "include" is not
found, the computation of the HBA or ident files is a hard failure, and
the full set of new rules will not be reloaded.  "include\_if\_exists" will
not complain that a file is missing, and the rules will be able to reload if
a file is missing.  Note that parsing errors in a file listed by
"include\_if\_exists" when the file exists causes a reload of the new rules
to fail.  Besides, the same rules as the files included via '@' apply for
the computation of the file paths with these commands:

  * If a relative path is defined, the file's path is compiled using as
  base location the path of the file currently being loaded.
  * If an absolute path is defined, this is used as-is.

As an effect of this change, the system views
[pg\_ident\_file\_mappings](https://www.postgresql.org/docs/devel/view-pg-ident-file-mappings.html)
and pg\_hba\_file\_rules have gained two columns each to allow users to
find all the information needed to debug data in included files:

  * Name of the file, kind of the most essential piece.
  * A rule ordering number, named map\_number for ident files and rule\_number
  for HBA files.  This indicates the order in which the rules are considered
  until one matches with a database and a role.  In 15 and older versions,
  knowing only about the line number of each rule is enough for this purpose.

Taking the previous example, pg\_hba\_file\_rules reports:

    =# SELECT rule_number AS order, file_name, line_number AS line, database, user_name, error
         FROM pg_hba_file_rules ;
     order |          file_name          | line | database | user_name |                   error
    -------+-----------------------------+------+----------+-----------+-------------------------------------------
         1 | /data/pg_hba_extra.conf     |    2 | {db_3}   | {user_3}  | null
         2 | /data/hba_conf/001_hba.conf |    2 | {db_1}   | {user_1}  | null
         3 | /data/hba_conf/002_hba.conf |    2 | {db_0}   | {user_0}  | null
      null | /data/hba_conf/002_hba.conf |    3 | null     | null      | invalid authentication method "incorrect"
    (4 rows)

As mentioned above, one of the rules is failing, causing a reload failure
so the new rules are not applied yet.

Have fun with this feature..
