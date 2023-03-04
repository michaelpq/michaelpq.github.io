---
author: Michael Paquier
lastmod: 2023-03-04
date: 2023-03-04 06:15:44+00:00
layout: post
type: post
slug: postgres-16-pghba-regexp
title: 'Postgres 16 highlight - More regexps in pg_hba.conf'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 16
- administration
- authentication

---

PostgreSQL 16 will normally, as there is always a risk of seeing something
reverted in the beta phase, include this
[commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=8fea868):

    commit: 8fea86830e1d40961fd3cba59a73fca178417c78
    author: Michael Paquier <michael at paquier xyz>
    date: Mon, 24 Oct 2022 11:45:31 +0900
    Add support for regexps on database and user entries in pg_hba.conf

    As of this commit, any database or user entry beginning with a slash (/)
    is considered as a regular expression.  This is particularly useful for
    users, as now there is no clean way to match pattern on multiple HBA
    lines.  For example, a user name mapping with a regular expression needs
    first to match with a HBA line, and we would skip the follow-up HBA
    entries if the ident regexp does *not* match with what has matched in
    the HBA line.

    [...]

    Author: Bertrand Drouvot
    Reviewed-by: Jacob Champion, Tom Lane, Michael Paquier
    Discussion: https://postgr.es/m/fff0d7c1-8ad4-76a1-9db3-0ab6ec338bf7@amazon.com

Most of the commit message has been cut, but feel free to refer to the link
above to get the full text as well as the code changes.  pg\_hba.conf controls
the authentication policy of a given cluster, with each line of this file
listing settings made of the authentication method, user name(s), database
name(s) and some host-related data (IP address, etc.).  When authenticating
to a server, one of the first step is to check each line of pg\_hba.conf
until there is a match for the user and the database given by the startup
message, to put it simply.  Once both match, the backend process then saves
the matching entry of pg\_hba.conf and moves on with the follow-up steps of
authentication depending on the authentication method and the extra options
registered in this line (pg_ident may involve a few more steps, as well,
when checking for the database and user matches).

As documented [here](https://www.postgresql.org/docs/current/auth-pg-hba-conf.html),
pg\_hba.conf already supports quite a few options to control how the user and
database strings should match.  So, in an HBA entry, it is possible to find as
special treatment for the user the following things:

  * When the user string is prefixed with '+', the backend process checks
  if the user provided by the client is a member of group in the HBA entry.
  * "all", to tell that all the users match.  Be careful when using that.
  * A direct user name string, if none of the other patterns map with the
  string.
  * A comma-separated list of such elements.

Then for the database:

  * "all", to tell that all the databases match.  Again, be careful with
  this option.
  * "sameuser", to force a patch if the requested database has the same name
  as the requested user.
  * "samerole", rather similar to the last one, with a membership check.
  * "replication" is a magic keyword that applies only to WAL senders able to
  do physical streaming.
  * A direct database name, if none of the other special patterns map with the
  string.
  * A comma-separated list of such elements can be defined.

Support for a new pattern is added in these sets: regular expressions, with
these expressions being compiled when they begin with a slash ('/') character.
The primary use case is to be able to map to a single HBA entry a large number
of users and/or databases.  Specifying "all" with an extra set of
configuration entries in pg\_hba.conf does not serve well in this case,
actually, because a match on an HBA line causes a hard failure if
pg\_ident.conf has no matches for the requested user, offering no way to
check for a match with the next HBA entries.  Hence, it becomes possible to
divide users into sub-categories, each one attached to one HBA entry.

Note that treating a string as a regular expression when it begins with a
slash ('/') forces, in itself, a backward-incompatible breakage with older
versions if a pg\_hba.conf file included lines with role names beginning
with this character, which would require Postgres to have such roles stored
in pg\_authid, as well.

With this feature in place, let's see some examples, like the following
pg\_hba.conf (by the way, *never* *ever* use "trust" in any production
deployment):

    # TYPE  DATABASE             USER                    METHOD
	local   "/^dbsystem\d{1,4}$" "/^systemuser\d{1,4}$"  scram-sha-256
    local   all                  "/^systemadmin\d{1,4}$" trust

The first entry allows any users named systemuserN, where N is a number
up to 4 digits (like "systemuser12", "systemuser9999", but not
"systemuser12345") to connect with SCRAM authentication on all databases
named dbsystemN (N is again a number up to 4 digits).  The second entry
would be for a set of admins, where roles named systemadminN (N is again
a number up to 4 digits) are authorized to connect without doing any
kind of authentication, as they are fully trusted, for all the requested
databases.  Note the quotes for the expressions, so as they can be single
elements in a comma-separated list because the expressions themselves may
include commas.  For example, this database entry would mean to check
for a match on "db1", "db2" and a database named "dbN", where N is a
2-to-3-digit number (the last entry is quoted):

	db1,db2,"/^db\d{2,3}$"

The compilation of the expressions happens when the backend parses
pg_hba.conf, and the execution is done at authentication time.  The
system view pg\_hba\_file\_rules is able to report compilation errors.
For example, take this entry:

	# TYPE DATABASE USER METHOD
	local  /db\.\   all  trust

This results in the following error:

    =# SELECT error FROM pg_hba_file_rules WHERE error IS NOT NULL;
                                 error                             
    ---------------------------------------------------------------
     invalid regular expression "db\.\": invalid escape \ sequence
    (1 row)

Extended authentication policies is not a niche case for organization
with complex rules (though LDAP also helps), so more flexibility is
nice.

This is not the only improvement done in this area of the code for
pg\_hba.conf and pg_ident.conf.  There is much more, but that's a
different story, for a different post.
