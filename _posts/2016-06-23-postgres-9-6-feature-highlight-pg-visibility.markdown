---
author: Michael Paquier
lastmod: 2016-06-23
date: 2016-06-23 05:25:46+00:00
layout: post
type: post
slug: postgres-9-6-feature-highlight-pg-visibility
title: 'Postgres 9.6 feature highlight - pg_visibility'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.6
- pg_visibility

---

PostgreSQL 9.6 is shipping with a new contrib module manipulating and
giving some input on the [visibility map](https://www.postgresql.org/docs/9.6/static/storage-vm.html)
of a relation:

    Add pg_visibility contrib module.

    This lets you examine the visibility map as well as page-level
    visibility information.  I initially wrote it as a debugging aid,
    but was encouraged to polish it for commit.

    Patch by me, reviewed by Masahiko Sawada.

    Discussion: 56D77803.6080503@BlueTreble.com

The visibility map, associated to a relation in its own file, which is
named with the suffix \_vm, tracks information related to the visibility
of tuples on relation pages for each backend. Up to 9.5, 1 bit was used
per heap page, meaning that if this bit is set all the tuples stored
on this page are visible to all the transactions. In 9.6, 2 bits are being
used, the extra bit added is used to track if all tuples on a given page
have been frozen or not, critically improving VACUUM performance by
preventing [full table scans](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=a892234f830e832110f63fc0a2afce2fb21d1584).

pg\_visibility contains a couple of functions allowing one to get a look
at the status of each page's bits. The first one, and aimed at general
purposes, gives an insight about the all-frozen and all-visible status
for each page of a relation, plus the status of PD\_ALL\_VISIBLE which
is the same information as the all-visible flag except that it is stored
in the heap page itself and not the VM file:

    =# CREATE TABLE tab_visible AS SELECT generate_series(1,1000) AS id;
    SELECT 1000
	=# SELECT * FROM pg_visibility('tab_visible'::regclass);
     blkno | all_visible | all_frozen | pd_all_visible
	-------+-------------+------------+----------------
         0 | f           | f          | f
         1 | f           | f          | f
         2 | f           | f          | f
         3 | f           | f          | f
         4 | f           | f          | f
    (5 rows)

This function can take an optional argument in the shape of a block
number. pg\_visibility\_map is similar to the previous function, except
that it does not scan the all-visible flag value on the page and it just
fetches what is available on the visibility map.

Then come the sanity checkers: pg\_check\_visible and pg\_check\_frozen
that return a list of TIDs where refer to tuples that are respectively
not all-visible and all-frozen even if the page they are on is marked as
such. Those functions returning an empty set means that the database is
not corrupted. If there are entries. Oops.

    =# SELECT pg_check_visible('tab_visible'::regclass);
     pg_check_visible
    ------------------
    (0 rows)
    =# SELECT pg_check_frozen('tab_visible'::regclass);
     pg_check_frozen
    -----------------
    (0 rows)

And finally is a function that may become useful for maintenance purposes:
pg\_truncate\_visibility\_map which removes the visibility map of a
relation. The next VACUUM that runs on this relation will forcibly rebuilt
the visibility map of the relation. Note that this action is WAL-logged.

    =# SELECT pg_truncate_visibility_map('tab_visible'::regclass);
     pg_truncate_visibility_map
    ----------------------------
     
    (1 row)
