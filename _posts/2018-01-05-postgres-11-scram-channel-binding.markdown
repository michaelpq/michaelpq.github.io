---
author: Michael Paquier
lastmod: 2018-01-05
date: 2018-01-05 12:31:01+00:00
layout: post
type: post
slug: postgres-11-scram-channel-binding
title: 'Postgres 11 highlight - Channel Binding for SCRAM'
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
- channel
- binding
- libpq
- connection
- parameter
- tls-unique
- tls-server-end-point
- mitm
- attack

---

This post is about a new feature of PostgreSQL 11 I have been working on
for the last couple of months, which has finally been merged into the
upstream repository. So if nothing goes wrong, we will have channel
binding support for SCRAM authentication in the next release of
Postgres. The feature set consists mainly of the following commits.
Here is the first one, which has added tls-unique:

    commit: 9288d62bb4b6f302bf13bb2fed3783b61385f315
    author: Peter Eisentraut <peter_e@gmx.net>
    date: Sat, 18 Nov 2017 10:15:54 -0500
    Support channel binding 'tls-unique' in SCRAM

    This is the basic feature set using OpenSSL to support the feature.  In
    order to allow the frontend and the backend to fetch the sent and
    expected TLS Finished messages, a PG-like API is added to be able to
    make the interface pluggable for other SSL implementations.

    This commit also adds a infrastructure to facilitate the addition of
    future channel binding types as well as libpq parameters to control the
    SASL mechanism names and channel binding names.  Those will be added by
    upcoming commits.

    Some tests are added to the SSL test suite to test SCRAM authentication
    with channel binding.

Then there is a second one to control how to use channel binding from
the client-side, for a libpq feature:

    commit: 4bbf110d2fb4f74b9385bd5a521f824dfa5f15ec
    author: Peter Eisentraut <peter_e@gmx.net>
    date: Tue, 19 Dec 2017 10:12:36 -0500
    Add libpq connection parameter "scram_channel_binding"

    This parameter can be used to enforce the channel binding type used
    during a SCRAM authentication.  This can be useful to check code paths
    where an invalid channel binding type is used by a client and will be
    even more useful to allow testing other channel binding types when they
    are added.

    The default value is tls-unique, which is what RFC 5802 specifies.
    Clients can optionally specify an empty value, which has as effect to
    not use channel binding and use SCRAM-SHA-256 as chosen SASL mechanism.

    More tests for SCRAM and channel binding are added to the SSL test
    suite.

And finally here is the last one, which adds support for
tls-server-end-point:

    commit: d3fb72ea6de58d285e278459bca9d7cdf7f6a38b
    author: Peter Eisentraut <peter_e@gmx.net>
    date: Thu, 4 Jan 2018 15:29:50 -0500
    Implement channel binding tls-server-end-point for SCRAM

    This adds a second standard channel binding type for SCRAM.  It is
    mainly intended for third-party clients that cannot implement
    tls-unique, for example JDBC.

Channel binding is a security-related feature aimed at preventing
man-in-the-middle attacks after doing the initial SSL handshake during
authentication by confirming that the server and the backend are still
the same. This is done, as defined by
[RFC 5929](https://tools.ietf.org/html/rfc5929) by using what is called
binding data, which depends on the SSL context where the connection is
done. There are two types of channel bindings which have been added:

  * tls-unique, which makes sure that a specific connection is used
  by using a 64b-encoded string coming from the TLS finished message,
  which is generated at the end of the SSL handshake.
  * tls-server-end-point, which uses a hash of the server certificate,
  which makes sure that the end points are the same. This will be
  useful for clients where trying to work with TLS unique data is
  cumbersome, like the Postgres JDBC driver.

Note that channel binding is specific to SSL. So if you attempt a
connection without a SSL context, the server will not publish the SASL
mechanism called SCRAM-SHA-256-PLUS (the suffix -PLUS is here to point
out that channel binding is supported), and the client will not select
it. The way to control how channel binding behaves during a SCRAM
authentication is done through a dedicated, new, connection parameter
called scram\_channel\_binding, which has the following properties:

  * A caller can specify the name of the channel binding to use.
  * The default, and as defined by the RFCs, is tls-unique.
  * An empty value allows the client to not use channel binding, and
  this even if the server has published the dedicated SASL mechanism.
  In this case the client sends SCRAM-SHA-256 as SASL mechanism for
  the exchange and enforces the binding flag to 'n', meaning no
  channel binding to use.

Note that during the development we noticed a couple of things.
tls-server-end-point can only be used with OpenSSL versions newer
than 1.0.2, as dedicated APIs are only available since this version.
This is caused by the necessary function X509\_get\_signature\_nid()
which is necessary to retrieve the hash algorithm used for a
certificate. This has been implemented by the following commit
in upstream OpenSSL:

    commit: dfcf48f499f19fd17a3aee03151ea301814ea6ec
    author: Dr. Stephen Henson <steve@openssl.org>
    date: Wed, 13 Jun 2012 13:08:12 +0000
    New functions to retrieve certificate signatures and signature OID NID.

The problem here is that any certificates using MD5 or SHA-1 need to use
SHA-256 for the server certificate hashing per the channel binding
specification, so some filtering needs to be done. So if you build
Postgres with an older version of OpenSSL and try to use
tls-server-end-point, then you will get a protocol error.

Then, as noticed on
[this thread](https://www.postgresql.org/message-id/CAB7nPqSFcNsuQcWcqhX8QSz0R8oKz8ZM4Yw4ky%3DcfO9rpVdTUA%40mail.gmail.com)
by Peter Eisentraut during the patch review for channel binding, is
that a v11 client was not able to connect to a v10 server in an SSL
context. So you will need at least v10.2 which is planned for February
2018 before being able to get that to work. This should not be an issue
as Postgres 11 is planned for the end of the year.

So, what's next? Well, from my point of view this finishes all the
features of SCRAM that I wanted to get into PostgreSQL, so I have no
plans to work on more features for SCRAM, still there are a couple of
things that could be considered (I am going to focus on some other
stuff for Postgres 12):

  * Allow the iteration count used in SCRAM verifiers to be
  configurable. The tricky part here is that you need to provide some
  handling on libpq side as well, while the server-side could use a
  dedicated GUC parameter. Until this happens, it is always possible
  to use workarounds like the one described in a
  [previous post](/postgresql-2/even-stronger-scram-verifier/).
  * Add an option for pg\_hba.conf which allows a server to override the
  use of channel binding for an HBA match if a client is trying to not
  use it. With the feedback I received during an unconference session
  done at [PGConf Asia last December](https://wiki.postgresql.org/wiki/PGConf.ASIA2017_Developer_Unconference#SCRAM_improvements),
  this may be not worth the code complications, and being able to
  control channel binding from the client is more appealing.
  * Work on protocol downgrades. A rogue server can still enforce
  MD5 to be used without the client being aware of it even if it
  would want to use SCRAM. This could become useful when forgetting
  to upgrade a server's configuration after a post-10 upgrade, but the
  impact seems limited.

I would like to thank primarily Peter Eisentraut who has provided a
bunch of feedback for the patch set and has helped in making it progress
in the good direction so as it has been merged into upstream Postgres.
Peter has found bugs on the way, and corrected me where I was wrong,
with at the end being the committer to merge the code into the tree.
