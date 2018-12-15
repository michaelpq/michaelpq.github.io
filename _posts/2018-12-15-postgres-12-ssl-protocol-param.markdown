---
author: Michael Paquier
lastmod: 2018-12-15
date: 2018-12-15 01:50:53+00:00
layout: post
type: post
slug: postgres-12-ssl-protocol-param
title: 'Postgres 12 highlight - Controlling SSL protocol'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 12
- ssl
- protocol

---

The following commit has happened in Postgres 12, adding a feature
which allows to control and potentially enforce the protocol SSL
connections can use when connecting to the server:

    commit: e73e67c719593c1c16139cc6c516d8379f22f182
    author: Peter Eisentraut <peter_e@gmx.net>
    date: Tue, 20 Nov 2018 21:49:01 +0100
    Add settings to control SSL/TLS protocol version

    For example:

    ssl_min_protocol_version = 'TLSv1.1'
    ssl_max_protocol_version = 'TLSv1.2'

    Reviewed-by: Steve Singer <steve@ssinger.info>
    Discussion: https://www.postgresql.org/message-id/flat/1822da87-b862-041a-9fc2-d0310c3da173@2ndquadrant.com

As mentioned in the commit message, this commit introduces two new GUC
parameters:

  * ssl\_min\_protocol_version, to control the minimal version used
  as communication protocol.
  * ssl\_max\_protocol_version, to control the maximum version used
  as communication protocol.

Those can also take different values, which defer depending on what the
version of OpenSSL PostgreSQL is compiled with is able to support or not,
with values going from TLS 1.0 to 1.3: TLSv1, TLSv1.1, TLSv1.2, TLSv1.3.
An empty string can also be used for the maximum, to mean that anything is
supported, which gives more flexibility for upgrades.  Note that within
a given rank, the latest protocol will be the one used by default.

Personally, I find the possibility to enforce that quite useful, as up to
Postgres 11 the backend has been taking automatically the newest protocol
available with SSLv2 and SSLv3 disabled by being hardcoded in the code.
However sometimes there are requirements which pop up, telling to make
sure that at least a given TLS protocol needs to be enforced.  Such things
would not matter for most users but for some large organizations sometimes
it makes sense to enforce some control.  This is also useful for testing a
protocol when doing development on a specific patch, which can happen when
working on things like SSL-specific things for authentication.  Another
area where this can be useful is if a flaw is found in a specific protocol
to make sure that connections are able to fallback to a safer default, so
flexibility is nice to have from all those angles.

From an implementation point of view, this makes use of a set of specific
OpenSSL APIs to control the minimum and maximum protocols:

  * SSL\_CTX\_set\_min\_proto\_version
  * SSL\_CTX\_set\_max\_proto\_version

These have been added in OpenSSL 1.1.0, still PostgreSQL provides a set
of compatibility wrappers which make use of SSL\_CTX\_set\_options for
older versions of OpenSSL, so this is not actually a problem when
compiling with other versions, especially since OpenSSL 1.0.2 is the
current LTS (Long-Time-Supported) version of upstream at this point.
