---
author: Michael Paquier
lastmod: 2023-04-05
date: 2023-04-05 05:15:15+00:00
layout: post
type: post
slug: postgres-16-scram-iterations
title: 'Postgres 16 highlight - Control of SCRAM iterations'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 16
- scram
- configure
- authentication

---

The SCRAM-SHA-256 authentication protocol, defined by
[RFC 7677](https://www.rfc-editor.org/rfc/rfc7677) and available since
PostgreSQL 10, uses SCRAM secrets. There are used during authentication as
equivalents of passwords and stored in
[pg_authid](https://www.postgresql.org/docs/devel/catalog-pg-authid.html),
shaped based on [RFC 5803](https://www.rfc-editor.org/rfc/rfc5803) for LDAP.
This format can be described as a string made of:

    <SCRAM mechanisms>$<iterations>:<salt>$<stored key>:<server key>

For all the details regarding that, feel free to look at the RFCs quoted
above.  When it comes to SCRAM-SHA-256 in PostgreSQL, the mechanism is
simply saved as "SCRAM-SHA-256", iterations are 4096, the salt is made of
16 random bytes.  These are default values hardcoded in PostgreSQL, still
the most internal routines (like scram\_build\_secret() in scram-common.c)
and the protocol are able to work in a very flexible way, hence it is
possible to have secrets with custom iteration values or salt lengths.  The
point is that secrets updated depending on these variables would be able to
work out of the box.  A few years ago, I have for example developed a small
extension called
[scram_utils](https://github.com/michaelpq/pg_plugins/tree/main/scram_utils),
able to customize SCRAM secrets and store them in the pg\_authid catalog
for a given role.  PostgreSQL has never by itself offered the possibility
to configure that in-core, which is what this post is about, but only for
the number of iterations, following this
[commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=b5777430)
that should land in Postgres 16:

    commit: b577743000cd0974052af3a71770a23760423102
    author: Daniel Gustafsson <dgustafsson@postgresql.org>
    date: Mon, 27 Mar 2023 09:46:29 +0200
    Make SCRAM iteration count configurable

    Replace the hardcoded value with a GUC such that the iteration
    count can be raised in order to increase protection against
    brute-force attacks.

    [...]

    Reviewed-by: Michael Paquier <michael@paquier.xyz>
    Reviewed-by: Jonathan S. Katz <jkatz@postgresql.org>
    Discussion: https://postgr.es/m/F72E7BC7-189F-4B17-BF47-9735EB72C364@yesql.se

The iteration number is a double-edged sword:

  * A low value means less time spent computing the salted password
  during authentication, speeding up the process.  However, passwords
  are more sensitive to brute-force attacks.
  * A high value uses more computing power to generate the salted
  password and it makes authentication longer, still it offers more
  protection.

As the commit message quotes, RFC 7677 recommends a default of 15000
iterations, while 4096 is the Postgres default, and it has also been
argued that even 4096 is still too expensive for some, which would mean
extra costs required by the user just for the sake of being able to connect
to a database and gain access to its data.  So this really is a balance
between what is thought as safe or affordable.  And, depending on the needs
and the requirements of an environment, honestly, satisfying either one of
them is simple: just use a low or upper bound.  Satisfying both, though,
means sacrifying a portion of the other for a range found acceptable.
The generation of the secret has two different costs:

  * Its initial creation in CREATE ROLE or ALTER ROLE.  This costs in
  computation resource in the backend if a password string is given in its
  clear form (perhaps not recommended), or some frontend, like libpq with
  psql's \password.
  * The connection attempt when computing the salted password in the
  frontend, after receiving the first message from the server during
  a SASL exchange for SCRAM.

Generating a secret can take some time with a high iteration number:

    =# SET scram_iterations = 4096;
    SET
    =# CREATE ROLE scram_4096 password 'foo';
    CREATE ROLE
    Time: 13.030 ms
    =# SET scram_iterations = 10000000;
    SET
    =# CREATE ROLE scram_10m password 'foo' LOGIN;
    CREATE ROLE
    Time: 5975.290 ms (00:05.975)
    =# SET scram_iterations = 1;
    SET
    =# CREATE ROLE scram_1 password 'foo' LOGIN;
    CREATE ROLE
    Time: 6.700 ms

A computation with 10M iterations took roughly 6s in a local environment,
while of course 1 iteration was, well, fast.  pg\_authid stores the iteration
number (barbaric regexp used here, so just look at the result):

    =# SELECT rolname,
              regexp_replace(rolpassword, '(SCRAM-SHA-256)\$(\d+):([a-zA-Z0-9+/=]+)\$([a-zA-Z0-9+=/]+):([a-zA-Z0-9+/=]+)', '\1$\2:<salt>$<storedkey>:<serverkey>') AS rolpassword_masked
         FROM pg_authid where rolname ~ '^scram';
      rolname   |                  rolpassword_masked
    ------------+-------------------------------------------------------
     scram_4096 | SCRAM-SHA-256$4096:<salt>$<storedkey>:<serverkey>
     scram_10m  | SCRAM-SHA-256$10000000:<salt>$<storedkey>:<serverkey>
     scram_1    | SCRAM-SHA-256$1:<salt>$<storedkey>:<serverkey>
    (3 rows)

As of the performance difference at authentication time, using a single psql
command with a simple query to stress how long it would take to run the
command is not fun.  One way I have learnt to stress the connection code
path of PostgreSQL *without* processing anything in the backend is to use
pgbench with an custom empty script, like that:

    $ cat /tmp/pgbench_empty.sql
    \set a 10

Combined with a fixed time defined by --time/-T, it is possible to quickly
check how many connection attempts (HBA entries set to local) could be achieved
in this given time frame (do not forget to set PGPASSWORD).  Here are some
quick numbers for each role defined previously (output has been cut a bit
for clarity):

    $ pgbench -n -T 30 -f /tmp/pgbench_empty.sql -C -U scram_4096 postgres
    number of transactions actually processed: 7099
    latency average = 4.226 ms
    average connection time = 4.226 ms
    tps = 236.613828 (including reconnection times)
    $ pgbench -n -T 30 -f /tmp/pgbench_empty.sql -C -U scram_10m postgres
    number of transactions actually processed: 5
    latency average = 6303.996 ms
    average connection time = 6303.993 ms
    tps = 0.158630 (including reconnection times)
    $ pgbench -n -T 30 -f /tmp/pgbench_empty.sql -C -U scram_1 postgres
    number of transactions actually processed: 18391
    latency average = 1.631 ms
    average connection time = 1.631 ms
    tps = 613.005891 (including reconnection times)

The number of connections achieved for 10M iterations does not sound as
a surprise, matching more or less with the number found when the secret
was computed by CREATE ROLE.  What is more surprising in this exercise
is the difference between 1 iteration and the default of 4096, so even for
short queries the default could really become a bottleneck.  That can be
leveraged with a connection pooler, as one workaround.  At the end, users
should make sure to study carefully what to use: security or speed.
