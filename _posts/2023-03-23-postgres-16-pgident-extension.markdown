---
author: Michael Paquier
lastmod: 2023-03-23
date: 2023-03-23 07:58:44+00:00
layout: post
type: post
slug: postgres-16-pgident-extension
title: 'Postgres 16 highlight - More patterns for pg_ident.conf'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 16
- administration
- authentication

---

Phase two of the improvements done in PostgreSQL 16 for authentication
configuration involve
[pg_ident.conf](https://www.postgresql.org/docs/devel/auth-username-maps.html),
mainly with this [commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=efb6f4a):

    commit: efb6f4a4f9b627b9447f5cd8e955d43a7066c30c
    author: Michael Paquier <michael@paquier.xyz>
    date: Fri, 20 Jan 2023 11:21:55 +0900
    Support the same patterns for pg-user in pg_ident.conf as in pg_hba.conf

    While pg_hba.conf has support for non-literal username matches, and
    this commit extends the capabilities that are supported for the
    PostgreSQL user listed in an ident entry part of pg_ident.conf, with
    support for:
    1. The "all" keyword, where all the requested users are allowed.
    2. Membership checks using the + prefix.
    3. Using a regex to match against multiple roles.

    [...]

    Author: Jelte Fennema
    Discussion: https://postgr.es/m/DBBPR83MB0507FEC2E8965012990A80D0F7FC9@DBBPR83MB0507.EURPRD83.prod.outlook.com

To put it simply, this commit applies the same rules as
[pg\_hba.conf](https://www.postgresql.org/docs/devel/auth-pg-hba-conf.html),
for what is referred as the PostgreSQL user in pg\_ident.conf, or the
database user.  This is the third entry in an ident mapping made of:

    map-name system-username database-username

The map-name is an identifier used with a matching HBA entry, while the two
others match with what they name, the database user being the role registered
in PostgreSQL itself.  system-username is able to be either an arbitrary
string or a regular expression (if beginning with a slash character), for many
years now.  database-username can also be defined for a pattern replacement
if it includes '\1' in its string, based on the system-user given by the client
when the system-user is a regular expression in the ident mapping.

Unfortunately, all that has its limitations up to PostgreSQL 15 in terms of
flexibility, as complex role ident policies can involve pg\_ident.conf files
with many entries that could refer to that many harcoded database role names.
Deployments can take advantage of the pattern replacement for the database
username with domain-based system usernames (like with Kerberos), but it
becomes more complicated to handle sub-categories of roles.  For example,
imagine a case where we would want to set up a cluster so as it allows a
system user named "my\_system\_user\_N" (0 =< N < 10^4) to match with some
arbitrary roles.  One can set up pg\_ident.conf to match a system user to
a set of PostgreSQL roles, in a rather straight-forward way:

    # MAP_NAME  SYSTEM-USER       PG-USER
    my_map      my_system_user_1  pg_role_1
    my_map      my_system_user_2  pg_role_2
	[ ... ]
    my_map      my_system_user_d  pg_role_N

Using a pattern replacement with \1 in the database user for an ident can be
actually rather flexible, however it limits the PostgreSQL role names to be
written in ways similar to the system names as they basically need a
subexpression in the system user that gets replaced in the PostgreSQL role
name, to match with what the client is giving.  Here is a simpler
pg_ident.conf that does the same as for the previous one, in one line:

    # MAP_NAME  SYSTEM-USER                    PG-USER
    my_map      "/^my_system_user_(\d{1,4})$"  my_pg_role_\1

Now imagine for example a pg_hba.conf like this one, with a single entry:

    # TYPE  DATABASE    USER      ADDRESS      METHOD
    local   all         all                    ident map=my_map

A system user named my\_system\_user\_N (0 <= N < 10^4) is authorized to log
in PostgreSQL only when using the database role with a matching number, which
would be my\_pg\_role\_N (like my\_system\_user\_123 => my\_pg\_role\_123).
While rather flexible, this finds its limitations when you want to group
multiple system users together in a single ident entry to match with a
group of PostgreSQL roles.

As explained in the commit message quoted at the beginning of this post, more
options are now available for the PostgreSQL user:

  * "all", to match with all the PostgreSQL user defined by the client.
  Applying double-quotes to the entry in the configuration file makes it
  lose its special meaning.
  * Membership check (like in CREATE ROLE .. IN ROLE), for entries beginning
  with a '+' character.
  * Regular expressions, for entries beginning with a '/' character.
  Subexpression replacements are not supported in this case (case where "\1"
  exists in the database role string).

The discussion that has led to this commit first mentioned that there should
be support for "all", later on arguing that regular expressions and membership
checks can be additionally useful.  At the end, supporting all of them has
proved to be the simplest solution implementation-wise, as this applies to the
database role string in an ident mapping the same set of checks applied to
roles in HBA entries, so both ident and HBA entries can rely on the same code
path for the same check, roughly.

For example, this is a possible configuration of pg\_ident.conf in 16:

    # MAP_NAME  SYSTEM-USER                    PG-USER
    my_map      "/^my_system_user_(\d{1})$"    all
    my_map      "/^my_system_user_(\d{2})$"    +my_role_group
    my_map      "/^my_system_user_(\d{3,4})$"  "/^my_pg_role_(\d{1,4})$"

With that in place, the connection policy rank is determined by the
number of digits used in the system user names:

  * 1-digit system users can connect with any PostgreSQL role.
  * 2-digit system users can connect as PostgreSQL roles that are members\
  of my\_role\_group.
  * 3-digit and 4-digit users can connect as PostgreSQL roles matching
  my\_pg\_role\_N where (0 <= N < 10^4).

Something to be extremely careful here: a greater control of authentication
configuration means a greater risk of bugs, hence always make sure to test
any configuration changes before deployment.  System views like
[pg\_ident\_file\_mappings](https://www.postgresql.org/docs/devel/view-pg-ident-file-mappings.html)
are vital here, particularly as failures of regular expression computations
are available there.
