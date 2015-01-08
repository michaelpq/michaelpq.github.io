---
author: Michael Paquier
lastmod: 2013-11-04
date: 2013-11-04 07:22:22+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-dates-with-more-than-5-digit-years
title: 'Postgres 9.4 feature highlight: dates with more than 5-digit years'
categories:
- PostgreSQL-2
tags:
- 9.4
- base
- cast
- database
- date
- development
- digit
- open source
- postgres
- timestamp
- timezone
- transfer
- year
---
When managing an MMORPG server of a science-fiction game, you may have noticed that all the dates that Postgres could store were limited to 4 digits for a YMD (Year/Month/Date), HMS (Hour/Minute/Second) or a year. This behavior has been improved with the following commit:

    commit 7778ddc7a2d5b006edbfa69cdb44b8d8c24ec1ff
    Author: Bruce Momjian
    Date: Wed Oct 16 13:22:55 2013 -0400
 
    Allow 5+ digit years for non-ISO timestamp/date strings, where appropriate
 
    Report from Haribabu Kommi

For example here is what happens for a 9.3 server or older version.

    =# CREATE TABLE aa (a int, b timestamptz);
    CREATE TABLE
    =# INSERT INTO aa VALUES (1, now() + interval '8000 years');
    INSERT 0 1
    =# INSERT INTO aa VALUES (2, to_timestamp('100000', 'YYYY'));
    INSERT 0 1
    =# INSERT INTO aa VALUES (3, 'Mon May 29 00:00:00 100000 IST');
    ERROR: 22007: invalid input syntax for type timestamp with time zone: "Mon May 29 00:00:00 100000 IST"
    LINE 1: INSERT INTO aa VALUES (3, 'Mon May 29 00:00:00 100000 IST')
    =# SELECT * FROM aa ORDER BY a;
     a | b
    ---+--------------------------------
     1 | 10013-11-04 22:23:13.259721+09
     2 | 100000-01-01 00:00:00+09
    (2 rows)

Note that only the direct insert is not working, it is of course possible to insert years with more than 4 digits with to\_timestamp as specified by [the documentation](http://www.postgresql.org/docs/devel/static/functions-formatting.html) where 'YYYY' means 4 digits or more, or via an indirect operation with interval.

And here is what is happening for a 9.4 server after the commit.

    =# INSERT INTO aa VALUES (1, now() + interval '8000 years');
    INSERT 0 1
    =# INSERT INTO aa VALUES (2, to_timestamp('100000', 'YYYY'));
    INSERT 0 1
    =# INSERT INTO aa VALUES (3, 'Mon May 29 00:00:00 100000 IST');
    INSERT 0 1
    =# SELECT * FROM aa ORDER BY a;
     a | ab
    ---+--------------------------------
     1 | 10013-11-04 22:18:56.623758+09
     2 | 100000-01-01 00:00:00+09
     3 | 100000-05-29 07:00:00+09
    (3 rows)

In this case, the dates written more than 5-digit years are simply created. Actually the new way of doing looks more consistent. This is not committed to other development versions as 9.3 and older versions as this would change the default spec of timestamp, so it will be available only from 9.4.
