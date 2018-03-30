---
author: Michael Paquier
lastmod: 2017-01-16
date: 2017-01-16 06:45:33+00:00
layout: post
type: post
slug: postgres-10-ssl-reload
title: 'Postgres 10 highlight - Reload of SSL parameters'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 10
- ssl
- security

---

Here are some news from the front of Postgres 10 development, with the
highlight of the following commit:

    commit: de41869b64d57160f58852eab20a27f248188135
    author: Tom Lane <tgl@sss.pgh.pa.us>
    date: Mon, 2 Jan 2017 21:37:12 -0500
    Allow SSL configuration to be updated at SIGHUP.

    It is no longer necessary to restart the server to enable, disable,
    or reconfigure SSL.  Instead, we just create a new SSL_CTX struct
    (by re-reading all relevant files) whenever we get SIGHUP.  Testing
    shows that this is fast enough that it shouldn't be a problem.

    In conjunction with that, downgrade the logic that complains about
    pg_hba.conf "hostssl" lines when SSL isn't active: now that's just
    a warning condition not an error.

    An issue that still needs to be addressed is what shall we do with
    passphrase-protected server keys?  As this stands, the server would
    demand the passphrase again on every SIGHUP, which is certainly
    impractical.  But the case was only barely supported before, so that
    does not seem a sufficient reason to hold up committing this patch.

    Andreas Karlsson, reviewed by Michael Banck and Michael Paquier

    Discussion: https://postgr.es/m/556A6E8A.9030400@proxel.se

This has been wanted for a long time. In some environments where Postgres is
deployed, there could be CA and/or CLR files installed by default, and the user
may want to replace them with custom entries. Still, in most cases, the
problems to deal with is the replacement of expired keys. In each case, after
replacing something that needs a reload of the SSL context, a restart of the
instance is necessary to rebuild it properly. Note that while it may be fine
for some users to pay the cost of an instance restart, some users caring about
availability do not want to have to take down a server, so this new feature
is most helpful for many people.

All the SSL parameters are impacted by this upgrade, and they are the
following ones:

  * ssl
  * ssl\_ciphers
  * ssl\_prefer\_server\_ciphers
  * ssl\_ecdh\_curve
  * ssl\_cert\_file
  * ssl\_key\_file
  * ssl\_ca\_file
  * ssl\_crl\_file

Note however that there are a couple of things to be aware of:

  * On Windows (or builds with EXEC\_BACKEND), the new parameters are read
  at each backend startup. Existing sessions do not have its context updated,
  and an error in loading the new parameters will cause the connection to
  fail.
  * Entries of pg\_hba.conf with hostssl are ignored are ignored if
  SSL is disabled and a warning is logged to mention that. In previous
  versions you would get an error if a hostssl entry was found at server
  start.
  * Passphrase key prompt is enabled, but only at server startup, and
  disactivated at parameter reload to not stuck every backend reloading
  the SSL context. There could be improvements in this area by using a new
  GUC parameter that defines command allowing processes to get the passphrase
  instead of asking it in a tty. Patches are welcome if there is a use case
  for it. This behavior is described in the following
  [commit](http://git.postgresql.org/pg/commitdiff/6667d9a6d77b9a6eac89638ac363b6d03da253c1).
  As passphrase support has been rather limited for a long time, being able
  to reload SSL contexts even without it has a great value.

This is really a nice feature, and I am happy to see this landing as I
have been struggling more than once with the downtime that a SSL update
induces.
