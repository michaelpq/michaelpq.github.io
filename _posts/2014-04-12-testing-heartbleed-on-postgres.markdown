---
author: Michael Paquier
comments: true
lastmod: 2014-04-12
date: 2014-04-12 05:07:04+00:00
layout: post
type: post
slug: testing-heartbleed-on-postgres
title: 'Testing heartbleed on Postgres'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- security
- vulnerability
- ssl
- openssl
- secret
- secure
- heartbleed
- blood
- heart
- password
- hack
- script
---
Except if you have been cut from the Internet the last week, you have already
heard of [Heartbleed](http://heartbleed.com/). This good candidate for the "Bug
of the Year 2014" price is already costing a better-not-to-count amount of money
in maintenance and development for many companies around the world.

It has already been [mentioned]
(http://blog.hagander.net/archives/219-PostgreSQL-and-the-OpenSSL-Heartbleed-vulnerability.html)
in which cases a PostgreSQL server would be vulnerable, but you might want
to run some tests to check that the update of openssl on your server is effective.
After this bug went public on 2014/04/07, many scripts have popped around on the
net to help you checking if a server is vulnerable to this bug or not. However,
you need to know that you may not be able to test them directly on a Postgres
server as Postgres uses a [custom protocol]
(http://www.postgresql.org/docs/devel/static/protocol-flow.html#AEN102260)
before handling the connection to openssl. A connection needs to send first
a message called SSLRequest described [here]
(http://www.postgresql.org/docs/devel/static/protocol-message-formats.html),
consisting of two 32-bit integers, 8 and 80877103. The server then answers
a single byte, either 'S' if SSL connection is supported, or 'N' if not.
Once 'S' is received the SSL startup handshake message can be sent for
further processing.

Taking that into account, an example of script usable to test Heartbleed
vulnerability on a Postgres server can be found [here]
(https://gist.github.com/hlinnaka/10458000), written by my colleague
Heikki Linnakangas. Particularly, note this portion of the code to
handle the PostgreSQL custom protocol:

    sslrequest = h2bin('''
    00 00 00 08 04 D2 16 2F
    ''')

    [...]

    print 'Sending PostgreSQL SSLRequest...'
    sys.stdout.flush()
    s.send(sslrequest)
    print 'Waiting for server response...'
    sys.stdout.flush()

    sslresponse = recvall(s, 1)
    if sslresponse == None:
      print 'Server closed connection without responding to SSLRequest.'
      return
    # Server responds 'S' if it accepts SSL, or 'N' if SSL is not supported.
    pay = struct.unpack('>B', sslresponse)
    if pay[0] == 0x4E: # 'N'
      print 'PostgreSQL server does not accept SSL connections.'
      return
    if pay[0] != 0x53: # 'S'
      print 'Unexpected response to SSLRequest: %d.', pay
      return

    # Continue with SSL start handshake...

The variable "sslrequest" is the hexadecimal conversion of SSLRequest
explained above. Now let's test that on a Linux box, Archlinux more
precisely. In order to reproduce the vulnerability openssl has been
temporarily downgraded to 1.0.1f as it was still available in the pacman
cache. A PostgreSQL server with ssl enabled has been deployed as well:

    $ pacman -Ss openssl | grep 1.0.1
    core/openssl 1.0.1.g-1 [installed: 1.0.1.f-2]
    $ psql -c "show ssl"
     ssl
    -----
     on
    (1 row)

Note the part "installed: 1.0.1.f" corresponding to the installed
version of openssl, which is not the one available through the packager.
And here is the result obtained when checking the vulnerability with
the script:

    $ ./ssltest.py 127.0.0.1 -p 5432 | tail -n 1
    WARNING: server returned more data than it should - server is vulnerable!

Yes server is vulnerable. Now let's see after an upgrade to 1.0.1g.

    $ pacman -Ss openssl | grep 1.0.1
    core/openssl 1.0.1.g-1 [installed]
    $ ./ssltest.py 127.0.0.1 -p 5432 | tail -n 1
    No heartbeat response received, server likely not vulnerable

Feeling better... Feel free to have a look at the script itself for
more details.
