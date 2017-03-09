---
author: Michael Paquier
lastmod: 2017-03-09
date: 2017-03-09 08:30:22+00:00
layout: post
type: post
slug: postgres-10-scram-authentication
title: 'Postgres 10 highlight - SCRAM authentication'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- 10
- feature
- highlight
- authentication
- password
- protocol
- method
- scram
- sha2
- scram-sha-256
- saslprep
- security
- attack
- mitm

---

Password are hashed by default in PostgreSQL using MD5, more and more voices
show up to mention that this is bad, particularly because it is possible
to log into a server by just knowing the contents of pg\_authid or find out
about those hashes in past backups still lying around. Normally this data
cannot be reached except by superusers, but things leaking sometimes, using
MD5 can prove to be insecure in some cases (even if MD5 is strong against
pre-image attacks for example). Postgres 10 is adding a new authentication
protocol with the following
[commit](http://git.postgresql.org/pg/commitdiff/818fd4a67d610991757b610755e3065fb99d80a5):

    Support SCRAM-SHA-256 authentication (RFC 5802 and 7677).

    This introduces a new generic SASL authentication method, similar to the
    GSS and SSPI methods. The server first tells the client which SASL
    authentication mechanism to use, and then the mechanism-specific SASL
    messages are exchanged in AuthenticationSASLcontinue and PasswordMessage
    messages. Only SCRAM-SHA-256 is supported at the moment, but this allows
    adding more SASL mechanisms in the future, without changing the overall
    protocol.

    Support for channel binding, aka SCRAM-SHA-256-PLUS is left for later.

    The SASLPrep algorithm, for pre-processing the password, is not yet
    implemented. That could cause trouble, if you use a password with
    non-ASCII characters, and a client library that does implement SASLprep.
    That will hopefully be added later.

    Authorization identities, as specified in the SCRAM-SHA-256 specification,
    are ignored. SET SESSION AUTHORIZATION provides more or less the same
    functionality, anyway.

    If a user doesn't exist, perform a "mock" authentication, by constructing
    an authentic-looking challenge on the fly. The challenge is derived from
    a new system-wide random value, "mock authentication nonce", which is
    created at initdb, and stored in the control file. We go through these
    motions, in order to not give away the information on whether the user
    exists, to unauthenticated users.

    Bumps PG_CONTROL_VERSION, because of the new field in control file.

    Patch by Michael Paquier and Heikki Linnakangas, reviewed at different
    stages by Robert Haas, Stephen Frost, David Steele, Aleksander Alekseev,
    and many others.

    Discussion: https://www.postgresql.org/message-id/CAB7nPqRbR3GmFYdedCAhzukfKrgBLTLtMvENOmPrVWREsZkF8g%40mail.gmail.com
    Discussion: https://www.postgresql.org/message-id/CAB7nPqSMXU35g%3DW9X74HVeQp0uvgJxvYOuA4A-A3M%2B0wfEBv-w%40mail.gmail.com
    Discussion: https://www.postgresql.org/message-id/55192AFE.6080106@iki.fi

To begin with, SCRAM authentication is part of the SASL protocol family, or [RFC 4422](https://tools.ietf.org/html/rfc4422]),
and is defined by [RFC 5802](https://tools.ietf.org/html/rfc5802).
Note that this is SCRAM-SHA-1. What has been implemented in Postgres with the
upper commit is SCRAM-SHA-256, described by [RFC 7677](https://tools.ietf.org/html/rfc7677).
Why this choice? The discussion around SCRAM methods has begun in 2013, and
between the moment when discussions have begun and now SCRAM-SHA-256 was
already out, so we have decided about implementing only the latest one.

The commit is pretty large mainly because it introduces all the infrastructure
necessary to support SASL at protocol level and it is made extensible, so as
future algorithms can be added in the future.

In order to use this feature, the configuration parameter password\_encryption
has been extended with the value 'scram', to allow the definition of passwords
hashed with SCRAM:

    =# SET password_encryption = 'scram';
    SET
    =#  CREATE ROLE foorole PASSWORD 'foo';
    CREATE ROLE
    =# SELECT substring(rolpassword, 1, 14) FROM pg_authid WHERE rolname = 'foorole';
       substring    
    ----------------
     scram-sha-256:
    (1 row)

First note that in the context of Postgres, the SCRAM verifier is made of a
couple of fields separated by colons which are used during the SASL challenge
during authentication:

  * A prefix "scram-sha-256", used for all such verifiers. This helps to make
  the difference between plain and MD5-hashed passwords.
  * An encoded salt.
  * The number of iterations to generate the verifier.
  * A base64-written stored key.
  * A base64-written server key.

In order to be able to use SCRAM in authentication, pg\_hba.conf can use the
keyword "scram". Note that "md5", "password" and "scram" cannot mix together.
Still it is perfectly possible to have a first rule using "md5" with a sub-list
of users, and a second rule below for all the other users to use "scram" or
even the reverse:

    host    all             @md5users       .myhost.com            md5
    host    all             all             .myhost.com            scram

Note as well that a SCRAM-hashed password cannot be used when "password" or
"md5" are used. However, users with a plain password stored can be identified
when the entry in pg\_hba.conf matches "scram".

This feature has been wanted for many years and by many people, so it is
really nice to see a first stone in the upstream code.

There are still a couple of items we are working on for this release:

  * Improve selection by client of the SASL exchange. For now only one
  method is supported but it is better to have in place an extensible
  protocol by letting the client what it wants to use based on a list
  supported by the server.
  * SASLprep (NFKC) is still missing. This is defined by
  [RFC 4013](https://tools.ietf.org/html/rfc4013). I have implemented
  a patch for that for some time now.
  * Extend CREATE/ALTER ROLE with a clause to enforce the hashing algorithm
  used for a password. Now using password\_encryption is the only way to
  do things. And that's actually basically enough if enforced at
  postgresql.conf level.
  * Perhaps make pg\_hba.conf more modular, as SASL is a large family of
  protocols.

The SCRAM protocol can be extended as well, particularly with channel
binding to help with MITM, but this bit won't be in Postgres 10, and that's
another story.
