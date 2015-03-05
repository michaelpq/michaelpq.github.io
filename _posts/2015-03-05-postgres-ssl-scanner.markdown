---
author: Michael Paquier
lastmod: 2015-03-05
date: 2015-03-05 08:16:54+00:00
layout: post
type: post
slug: postgres-ssl-scanner
title: 'sslyze, a SSL scanner supporting Postgres'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- security
- ssl
- openssl
- scanner

---

The last months have showed a couple of vulnerabilities in openssl, so
sometimes it is handy to get a status of how SSL is used on a given
instance. For this purpose, there is a nice tool called
[sslyze](https://github.com/nabla-c0d3/sslyze) that can help scanning SSL
usage on a given server and it happens that it has support for the
SSLrequest handshake that PostgreSQL embeds in its protocol (see [here]
(http://www.postgresql.org/docs/devel/static/protocol-flow.html) regarding
the message SSLrequest for more details).

The invocation of Postgres pre-handshake, support added recently with this
[commit]
(https://github.com/nabla-c0d3/sslyze/commit/ddd18d6e49ccd65356c3db1d9c33533784caed7b),
can be done using --starttls=postgres. With "auto", the utility can guess
that the Postgres protocol needs to be used thanks to the port number.

Something important to note is that when writing this blog post the last
release of sslyze does not include the support of Postgres protocol, so it
is necessary to fetch the raw code from github, and to add nassl/ in the
root of the git code tree to have the utility working (simply fetch it
from the last release build for example).

Once the utility is ready, simply scan a server with SSL enabled with
a command similar to that:

    python sslyze.py --regular --starttls=postgres $SERVER_IP:$PORT

PORT would be normally 5432.

Now let's take the case of for example EXPORT ciphers which are not
included by default in the list of ciphers available on server. The
scanner is able to detect their presence:

    $ python sslyze.py --regular --starttls=postgres $SERVER_IP:5432 | grep EXP
    EXP-EDH-RSA-DES-CBC-SHA       DH-512 bits    40 bits
    EXP-EDH-RSA-DES-CBC-SHA       DH-512 bits    40 bits
    EXP-EDH-RSA-DES-CBC-SHA       DH-512 bits    40 bits
    $ psql -c 'show ssl_ciphers'
             ssl_ciphers
    ------------------------------
     HIGH:MEDIUM:EXP:+3DES:!aNULL
    (1 row)

And once disabled the contrary happens:

    $ python sslyze.py --regular --starttls=postgres $SERVER_IP:5432 | grep EXP
    $ psql -c 'show ssl_ciphers'
              ssl_ciphers
    -------------------------------
     HIGH:MEDIUM:!EXP:+3DES:!aNULL
    (1 row)

This makes this utility quite a handy tool to get a full status of a given
server regarding SSL.
