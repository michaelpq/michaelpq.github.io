---
author: Michael Paquier
lastmod: 2023-04-13
date: 2023-04-13 03:30:15+00:00
layout: post
type: post
slug: 2023-04-13-postgres-16-require-auth
title: 'Postgres 16 highlight - require_auth for libpq'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 16
- authentication
- libpq

---

A feature has been committed in Postgres 16 for libpq to bring more
filtering capabilities over the authentication methods authorized
on a new connection. Here is the
[commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=3a465cc6):

    commit: 3a465cc6783f586096d9f885c3fc544d82eb8f19
    author: Michael Paquier <michael@paquier.xyz>
    date: Tue, 14 Mar 2023 14:00:05 +0900
    libpq: Add support for require_auth to control authorized auth methods

    The new connection parameter require_auth allows a libpq client to
    define a list of comma-separated acceptable authentication types for use
    with the server.  There is no negotiation: if the server does not
    present one of the allowed authentication requests, the connection
    attempt done by the client fails.

    [...]

    Author: Jacob Champion
    Reviewed-by: Peter Eisentraut, David G. Johnston, Michael Paquier
    Discussion: https://postgr.es/m/9e5a8ccddb8355ea9fa4b75a1e3a9edc88a70cd3.camel@vmware.com

The implementation of this feature relies internally in the authentication
request codes exchanged by the backend and the frontend at authentication,
respecting the folowwing protocol flow, roughly:

  * The client sends a user name and a database name in its startup package.
  * The backend receives these fields, then checks with
  [pg\_hba.conf](https://www.postgresql.org/docs/devel/auth-pg-hba-conf.html)
  until a record matching is found.
  * The backend retrieves the authentication method for the record, calls
  sendAuthRequest() and sends a 32-bit integer based on the list of
  AUTH\_REQ\_* codes in src/include/libpq/pqcomm.h.
  * The client moves on with the authentication received, that may involve
  one of more extra exchanges with the backend.

SSL negotiation and client certifications work on top of that.  The feature
committed here works as a filter of the AUTH\_REQ\_* code received from the
backend, to allow the client to fail hard if the authentication request number
received does not match with what's expected by the client.  A reason why this
has been implemented is that libpq gives little protection against downgrade
attacks, that has been a problem for many years.  For example, a client may
want SCRAM, or MD5, but it could be silently tricked by a rogue server that
immediately sends AUTH\_REQ\_OK, if for example the pg\_hba.conf found to
match with the user name and the database name uses "trust".  A similar case
could be a client willing to use SCRAM-SHA-256, but the server could also
force a weaker MD5 on-the-fly.

There is already something in place to prevent such problems with the
connection parameter
[channel_binding](https://www.postgresql.org/docs/devel/libpq-connect.html#LIBPQ-CONNECT-CHANNEL-BINDING),
that would check if authentication has relied on channel binding, but
this is limited to SCRAM-SHA-256 with a SASL exchange, only for a
SSL connection, so for users that rely on other authentication method
this is of no help.

This time, more control is given via a new connection parameter called
[require_auth](https://www.postgresql.org/docs/devel/libpq-connect.html#LIBPQ-CONNECT-REQUIRE-AUTH),
with a complementary environment variable called PGREQUIREAUTH, able to
use a *list* of authorized connection methods.  The parameters that can
be defined map with their respective authentication request codes:

  * "password", for AUTH\_REQ\_PASSWORD.
  * "md5", for AUTH\_REQ\_MD5.
  * "gss", for AUTH\_REQ\_GSS and AUTH\_REQ\_GSS\_CONT.
  * "sspi", for AUTH\_REQ\_SSPI and AUTH\_REQ\_GSS\_CONT.  Note the overlap
  with GSS, but this method is Windows-specific.
  * "scram-sha-256", for AUTH\_REQ\_SASL, AUTH\_REQ\_SASL\_CONT and
  AUTH\_REQ\_SASL\_FIN.
  * A bonus value with "none", to provide control on unauthenticated
  connections like "trust" where AUTH\_REQ\_OK is directly received from the
  server before attempting any kind of authentication.

"creds", for AUTH\_REQ\_SCM\_CREDS, was also possible, but this was dead code
in libpq.   This was left around as a way to use SCM credential authentication
with backends of PostgreSQL 9.1 or older versions, now removed with
[this commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=98ae2c84).
The original commit for require\_auth had to handle this case.

A key point is that the authentication request code received by the server
is checked before the authentication exchange, so as no sensitive information
is sent in case something unexpected happens.  This comes from the
introduction of channel\_binding, and this feature relies on the same code
path.

For example, let's take a server with the following, simple configuration
that authorizes only local connections with SCRAM-SHA-256:

    $ cat $PGDATA/pg_hba.conf
    # TYPE  DATABASE   USER    METHOD
    local   all        all     scram-sha-256
    $ psql -c "SELECT rule_number, type, database, user_name, auth_method FROM pg_hba_file_rules;"
     rule_number | type  | database | user_name |  auth_method
    -------------+-------+----------+-----------+---------------
               1 | local | {all}    | {all}     | scram-sha-256
    (1 row)

require\_auth works as long as it includes "scram-sha-256" in its list:

    $ psql -d "require_auth=md5,scram-sha-256" -c "" 1> /dev/null && echo $?
    0
    $ psql -d "require_auth=gss,md5" -c "" 1> /dev/null && echo $?
    psql: error:
      connection [..] failed: auth method "gss,md5" requirement failed:
      server requested SASL authentication

Note that specifying both channel\_binding and require\_auth is possible,
and libpq considers that as an AND condition.  Local connections don't use
channel binding, so this configuration fails even if require_auth allows
SCRAM-SHA-256:

    $ psql -d "require_auth=md5,scram-sha-256 channel_binding=require" -c "" 1> /dev/null && echo $?
    psql: error: connection [..] failed: channel binding required, but SSL not in use

Negated entries can be specified in a list by prefixing an element with '!'.
Negated and normal elements cannot be mixed.  Applied to a backend
configuration based on SCRAM, authentication will pass as long as
"!scram-sha-256" is *not* listed:

    $ psql -d "require_auth=\!md5,scram-sha-256" -c "" 1> /dev/null && echo $?
    psql: error:
      require_auth method "scram-sha-256" cannot be mixed with negative methods
    $ psql -d "require_auth=\!scram-sha-256,\!md5" -c "" 1> /dev/null && echo $?
    psql: error:
      connection [..] failed: auth method "!scram-sha-256,!md5" requirement failed:
      server requested SASL authentication
    $ psql -d "require_auth=\!md5,\!gss" -c "" 1> /dev/null && echo $?
    0

One last thing to know is the particular case of "none", that does not map
with any of the internal authentication request used by the protocol.  This
means that the client should *never* prompt for any authentication requests.
If negated with "!none", the check passes as long as authentication happens:

    $ psql -d "require_auth=\!none" -c "" 1> /dev/null && echo $?
    0
    $ psql -d "require_auth=none" -c "" 1> /dev/null && echo $?
    psql: error:
      connection [..] failed: auth method "none" requirement failed:
      server requested SASL authentication

This can become handy to filter out servers configured with "trust", like
this one:

    $ cat $PGDATA/pg_hba.conf
    # TYPE  DATABASE   USER    METHOD
    local   all        all     trust
    $ psql -d "require_auth=none" -c "" 1> /dev/null && echo $?
    0
    $ psql -d "require_auth=\!none" -c "" 1> /dev/null && echo $?
    psql: error:
      connection [..] failed: auth method "!none" requirement failed:
      server did not complete authentication

Be careful that this does not provide coverage for GSS encryption and SSL,
where equivalent connection parameters like
[sslmode](https://www.postgresql.org/docs/devel/libpq-connect.html#LIBPQ-CONNECT-SSLMODE)
or [gssencmode](https://www.postgresql.org/docs/devel/libpq-connect.html#LIBPQ-CONNECT-GSSENCMODE)
offer more options.
