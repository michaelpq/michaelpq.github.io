---
author: Michael Paquier
lastmod: 2017-12-26
date: 2017-12-26 03:27:43+00:00
layout: post
type: post
slug: even-stronger-scram-verifier
title: 'Even stronger scram verifiers'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- scram
- authentication
- verifier
- password
- iteration
- salt
- length
- computation
- cost

---

As designed by [RFC 7677](http://www.ietf.org/rfc/rfc7677.txt) and
[RFC 5802](http://www.ietf.org/rfc/rfc5802.txt), SCRAM verifiers (please
take this term as a password if you want, which means a proof of
authentication) are defined with default parameters which make the
computation of a proof costly, making it more expensive to do dictionary
or brute-force attacks while offline. Longer nonces help in making the
computation longer, but there are as well two parameters that help in
deciding such computation time and strength to offline attacks:

  * The iteration count used for the proof.
  * The salt length used to store the server-side proof.

By default, Postgres uses 4096 for the iteration count, and 16 for
the salt length. Those are considered as safe enough by default, still
some users may consider more useful to have higher numbers to mitigate
even more attack risks. Even if there is no way to refine those numbers
when creating a SCRAM verifier for a role using DDL commands like CREATE
ROLE, ALTER ROLE, or even psql's \password, the SCRAM protocol supports
longer (or smaller!) iteration counts and salt lengths. Postgres also
provides a set of low-level APIs which allow more customization, and in
this case scram\_build\_verifier() in scram-common.h becomes handy, because
wrapped in an extension one can define SCRAM verifiers with a higher level
of customization, and this is what
[scram\_utils](https://github.com/michaelpq/pg_plugins/tree/master/scram_utils)
does for this post, which is part of my set of
[Postgres plugins](https://github.com/michaelpq/pg_plugins).

Once compiled and deployed, it comes with a single, simple function:

    =# CREATE EXTENSION scram_utils;
    CREATE EXTENSION
    =# \dx+ scram_utils
                Objects in extension "scram_utils"
                        Object description
    ----------------------------------------------------------
     function scram_utils_verifier(text,text,integer,integer)
    (1 row)

This function will generate and insert a SCRAM verifier in pg\_authid using
the following data:

  * A user name.
  * A password string.
  * An iteration number.
  * A salt length.

Be careful though, a higher number of iteration and a higher salt length
means that it takes more time to compute the authentication proof, so the
time it takes to perform a connection. And when doing this game a higher
iteration count matters a lot. After playing a bit with this extension,
it can take a long time to log in depending on the iteration. Here are
some numbers from my laptop:

  * 4,096, the default, is painless, and takes less than 10ms.
  * 2,000,000 takes 2s.
  * 20,000,000 takes 18s.
  * 200,000,000 takes close to 180s.

So offline defense has a cost, and in some cases this extension can
become handy. Note that this is compatible with PostgreSQL 10, and that
if you are worried about sending a password string over the wire you
might consider patching psql's \password command which would take care
of sending to the server an already-computed verifier.
