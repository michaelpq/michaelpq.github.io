---
author: Michael Paquier
lastmod: 2017-06-07
date: 2017-06-07 09:20:22+00:00
layout: post
type: post
slug: scram-drivers
title: 'Support for SCRAM in PostgreSQL drivers'
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
- scram
- authentication
- driver
- go
- perl
- python
- java
- odbc

---

The addition of SCRAM-SHA-256 is proving to have many benefits in PostgreSQL
over MD5, but it has required an extension of the authentication protocol so
as message exchanges for SASL authentication are able to work correctly. A lot
of details on this matter are defined in the
[documentation](https://www.postgresql.org/docs/devel/static/sasl-authentication.html):

  * When beginning the SASL authentication, the server sends a list of
  mechanisms that it supports. In Postgres 10 only SCRAM-SHA-256 is supported
  (definition by IANA). In the future more of them could be added, like
  SCRAM-SHA-256-PLUS which is the same as the latter with support for channel
  binding. Note that the message format is predefined, as a list of
  zero-terminated string with an empty string as last element of the list.
  * The client chooses the mechanism it wants to use with the server, which
  is a unique choice for now.
  * Then follows a set of messages exchanged. In the case of SCRAM those
  messages is are roughly a challenge from the server and response to it by
  the client.
  * Once the exchange completes, the server sends back a finalization message.

As this facility is already implemented in libpq, all drivers that do not
speak directly the PostgreSQL protocol do not need any work, like ODBC for
example: everything works out-of-the-box. However, there are some drivers
that need some work to support SCRAM, like:

  * [Crystal](https://github.com/will/crystal-pg/commits/master), which has
  no support yet.
  * [Go](https://github.com/lib/pq), in which case there is a
  [patch](https://github.com/lib/pq/pull/608) lying around, waiting for
  review.
  * [Npgsql](npgsql.projects.postgresql.org), where there is no package
  yet.
  * [JDBC](https://jdbc.postgresql.org/), where a patch is in the works.
  * [Node](https://github.com/brianc/node-postgres), the use of libpq being
  optional here, things are still possible.

The PostgreSQL wiki maintains a list of all the drivers related to the project
[here](https://wiki.postgresql.org/wiki/List_of_drivers), so if you know about
an extra driver that is not listed in it, feel free to add it.

Note as well that some work is planned to add channel binding in Postgres 11,
so any implementation done should be careful enough to handle multiple
mechanism names received from the server. The current plan is to implement
two channel binding types as listed in
[RFC 5929](https://tools.ietf.org/html/rfc5929):

  * tls-unique, which uses the TLS finish message.
  * tls-server-end-point, which uses a hash of the TLS server certificate
  for validation.

Any implementation of channel binding must have tls-unique, and for
OpenSSL this data can be fetched thanks to two undocumented APIs,
SSL\_get\_peer\_finished() and SSL\_get\_finished(). For some drivers
putting their hands on this data may require some extra, unwelcome
dependencies, which is actually the case of the JDBC driver. So if you
are a driver maintainer, feel free to drop any opinion on the thread
dedicated to the channel binding development of SCRAM that is
[here](https://www.postgresql.org/message-id/CAB7nPqTZxVG9Lk0Ojg7wUR4mhGGd_W=Qa4+7wuhy6k75kE9keg@mail.gmail.com).
