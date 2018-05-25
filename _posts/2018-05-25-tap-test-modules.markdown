---
author: Michael Paquier
lastmod: 2018-05-25
date: 2018-05-25 09:25:32+00:00
layout: post
type: post
slug: tap-test-modules
title: 'TAP tests and external modules'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- regression

---

PostgreSQL TAP test has become over the last couple of years an advanced
facility gaining in more and more features which allow for complicated
regression test scenarios written in perl, with perl 5.8.0 being a minimum
requirement.  As of now, TAP tests are divided into different pieces in
the code tree:

  * src/test/perl/ contains the core set of modules.  PostgresNode.pm
  is usually of the main interest as it allows to set up nodes, run
  psql on them, take base backups, etc.  perldoc can also be used on
  them to get documentation about all the existing facilities.
  * Each binary in src/bin/ has its own set of tests, like initdb,
  pg\_basebackup, etc.  Those are the oldest ones, which have been introduced
  at the same time as the first Postgres TAP modules as of version 9.4.
  * src/test/recovery, set of tests mainly for replication and recovery.
  This is also one ancestor of most of the others since the introduction of
  PostgresNode.pm.
  * src/test/ssl, set of tests for OpenSSL, which is present for a couple
  of releases now.
  * src/test/authentication, introduced in Postgres 10, which has tests
  paths for SASLprep in SCRAM authentication.
  * src/test/subscription, for logical replication, and present since 10.
  * src/test/kerberos, set of tests for krb5, new as of 11.
  * src/test/ldap, which has tests for OpenLDAP, new as of 11.

Note that some of those tests are not designed to be able to run in
shared environments as they would need to run Postgres while listening
on hosts which are available to all, which is the case of the SSL,
Kerberos and LDAP tests.  Note that in v11 an environment variable has
been added to run those tests automatically, called PG\_TEST\_EXTRA, so
this can be used to automate all test runs in a consistent way:

    PG_TEST_EXTRA='ssl ldap kerberos'

All basic TAP modules are installed with each PostgreSQL installation
as part of lib/pgxs/src/test/perl/, so it is possible to include and
run TAP tests within custom modules.  One thing to know first is that
the makefile of the module would need to be updated.  In the most
simplified way, if one wishes to keep make targets consistent with
upstream for regression tests, one could just use that:

    check:
            $(prove_check)
    installcheck:
            $(prove_installcheck)

Also, when setting up a PostgreSQL cluster, using the pg\_regress command
is a necessary requirement as it can be used to set up nodes in a way
which does not harm in ways described by
[CVE-2014-0067](https://access.redhat.com/security/cve/cve-2014-0067),
however when trying to use PostgresNode.pm directly you will see failures,
so tests need to be made aware of the location of the command and then
set the environment variable PG\_REGRESS in the run.  One trick that
I have found handy here is to use pg\_config --libdir to find the base
location, and then register the location before initializing nodes, like
that for example.

    use strict;
    use warnings;
    use PostgresNode;

    # Run a simple command and grab its stdout output into a result
    # given back to caller.
    sub run_simple_command
    {
        my ($cmd, $test_name) = @_;
        my $stdoutfile = File::Temp->new();
        my $stderrfile = File::Temp->new();
        my $result = IPC::Run::run $cmd, '>', $stdoutfile, '2>', $stderrfile;
        my $stdout = slurp_file($stdoutfile);

        ok($result, $test_name);
        chomp($stdout);
        return $stdout;
    }

    # Look at the binary position of pg_config and enforce the
    # position of pg_regress to what is installed.
    my $stdout = run_simple_command(['pg_config', '--libdir'],
        "fetch library directory using pg_config");
    print "LIBDIR path found as $stdout\n";
    $ENV{PG_REGRESS} = "$stdout/pgxs/src/test/regress/pg_regress";

prove\_installcheck could be made smarter here, but there nothing to
prevent the integration of TAP tests even in externally-maintained
modules.  So happy test-hacking.
