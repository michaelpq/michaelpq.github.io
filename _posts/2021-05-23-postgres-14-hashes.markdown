---
author: Michael Paquier
lastmod: 2021-05-23
date: 2021-05-23 12:58:12+00:00
layout: post
type: post
slug: postgres-14-hashes
title: 'Postgres 14 highlight - Fun with Hashes'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 14
- scram
- security

---

PostgreSQL has a long history with cryptographic hashes, coming into three
parts, roughly.  First, MD5 authentication, that exists in PostgreSQL since
2001 in this [commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=38bb1abc).
This feature has come up with its own implementation of this hash in
either src/common/md5.c or src/backend/libpq/md5.c, depending on the branch
of the code checked out.  This is then used by libpq or the backend code.
One thing to know is that this code gets used even when building PostgreSQL
with OpenSSL, library that has its own APIs to be able to build MD5 hashes.

The second piece of history is within
[pgcrypto](https://www.postgresql.org/docs/devel/pgcrypto.html), that supports
its own set of cryptographic hashes when PostgreSQL is not built with OpenSSL:
MD5, SHA-1, SHA-2, AES, Blowfish, etc.  See on the link of its documentation,
where any algorithm supported by OpenSSL could be picked when using pgcrypto.
Coming back to the first point about MD5, this means that PostgreSQL, up to 13,
included in its code two fallback implementations for MD5.

The third piece of history is SCRAM-SHA-256, a password-based authentication
method that has been added in PostgreSQL 10, as of this
[commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=818fd4a6)
from 2017.  As per its name, this method uses SHA-256 and HMAC in the set of
messages exchanged during authentication and in the build of the SCRAM secret.
When working on that, PostgreSQL has refactored the SHA-2 code from pgcrypto
and added it into src/common/ as a way to have a fallback implementation when
not building the code with OpenSSL (SHA-2 goes through OpenSSL when building
with it), allowing SCRAM to work for libpq and the backend code (note that
libpq needs to be able to build SCRAM secrets to be store within
pg\_authid.rolpassword for \password in psql so as there is no need to send
the password directly over-the-wire for some users).  Another thing to note
is that SCRAM has added back in 2017 its own implementation of HMAC, using
SHA-256, that one may find in the internals of src/common/scram-common.c up
to Postgres 13.

The last interesting piece in all that is OpenSSL itself and the APIs that
Postgres uses to build cryptographic hashes, based on some low-level layer
of OpenSSL with routines like
[MD5\_Init](https://www.openssl.org/docs/man1.0.2/man3/MD5_Init.html),
[SHA256\_Update](https://www.openssl.org/docs/manmaster/man3/SHA256_Update.html),
etc.  Those routines are officially deprecated in OpenSSL 3.0.0, and upstream
recommends to not use them since the years 2000 if my memory serves well.
So Postgres has lagged behind for many years, as OpenSSL recommends to use the
routines based on EVP, like
[EVP\_DigestInit\_ex](https://www.openssl.org/docs/manmaster/man3/EVP_DigestInit_ex.html).
The fun does not stop here either, as when working with FIPS enabled,
OpenSSL 1.0.2 has the idea to just die, as per this code in crypto/crypto.h:

    # ifdef OPENSSL_FIPS
    #  define fips_md_init_ctx(alg, cx) \
        int alg##_Init(cx##_CTX *c) \
    { \
    if (FIPS_mode()) OpenSSLDie(__FILE__, __LINE__, \
        "Low level API call to digest " #alg " forbidden in FIPS mode!"); \
    return private_##alg##_Init(c); \
    } \
    int private_##alg##_Init(cx##_CTX *c)

In short, any caller of such low-level cryptohash routines would just crash
when going through OpenSSL.  In Postgres, MD5 and SCRAM authentications,
or even the SQL functions able to build such hashes could call that.

The list of problems is long here, and one thing that I have been working
on for this release was to put more sanity in this area.  This has resulted
in a series of commits that basically refactor all the code related to
cryptographic hashes, where possible:

  * [Move SHA2 routines into new design](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=87ae969)
  * [Refactor MD5](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=b67b57a)
  * [Refactor SHA1](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=a8ed6bb)
  * [Refactor HMAC](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=e6bdfd9)

Once a design was set in stone, then comes the boring part make sure that
everything is able to stick with the decisions made.  And at the end, the
gains are neat:

  * A single window for all the crypto hash calls, with support for MD5,
  SHA-1 (this one was added as it cleaned up some code in contrib/) and
  the four SHA-2.
  * Elimination of one fallback implementation for MD5, the one coming
  from pgcrypto being moved to src/common/, used whe not building Postgres
  with OpenSSL.
  * While on it, removal of the HMAC implementation that existed within
  the internals of the SCRAM code.  This means that SCRAM uses OpenSSL
  for HMAC and SHA-256 related business when building with its support.
  Fallback implementations exist so as things work when not building with
  OpenSSL, of course.
  * When using OpenSSL, all cryptographic hashes go through OpenSSL, and
  use the EVP routines and not the low-level routines anymore, so things
  can work even with the FIPS code mentioned above that would cause a
  hard crash.

The last point is something that has influenced a lot the set of interfaces
to initialize, update and finalize the hashes supported.  OpenSSL does the
allocations of all the structures used for the hashes and these remain
internal, applications manipulating only pointers to them.  The low-level
hash routines were much more flexible here.  So this has made necessary the
creation of two routines, one for the allocation of the hash structures and
a second one to free them.  libpq requires a soft error in the event of
out-of-memory errors so as client applications can catch errors reliably,
so several layers required to become more careful with their error reporting.
The backend uses resource owners to make sure that any allocation done by
OpenSSL is tracked and that things get cleaned up when the parent context is
released and free()'d.  Anyway, here is the set of routines designed, as of
src/include/common/cryptohash.h (similar for HMAC in
src/include/common/hmac.h):

    extern pg_cryptohash_ctx *pg_cryptohash_create(pg_cryptohash_type type);
    extern int  pg_cryptohash_init(pg_cryptohash_ctx *ctx);
    extern int  pg_cryptohash_update(pg_cryptohash_ctx *ctx, const uint8 *data, size_t len);
    extern int  pg_cryptohash_final(pg_cryptohash_ctx *ctx, uint8 *dest, size_t len);
    extern void pg_cryptohash_free(pg_cryptohash_ctx *ctx);

In the long term, this is a solution that can be relied on, and those
routines can be plugged with other SSL libraries (this may happen in
the future to offer alternatives to OpenSSL when using Postgres).
