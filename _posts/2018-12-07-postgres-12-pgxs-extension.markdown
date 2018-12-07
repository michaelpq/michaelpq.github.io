---
author: Michael Paquier
lastmod: 2018-12-07
date: 2018-12-07 10:30:44+00:00
layout: post
type: post
slug: postgres-12-pgxs-extension
title: 'Postgres 12 highlight - New PGXS options for isolation and TAP tests'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 12
- regression

---

If you maintain some PostgreSQL extensions which rely on
[PGXS](https://www.postgresql.org/docs/devel/extend-pgxs.html), a build
infrastructure for PostgreSQL, the following commit added to Postgres
12 will be likely something interesting, because it adds new options
to control more types of regression tests:

    commit: d3c09b9b1307e022883801000ae36bcb5eef71e8
    author: Michael Paquier <michael@paquier.xyz>
    date: Mon, 3 Dec 2018 09:27:35 +0900
    committer: Michael Paquier <michael@paquier.xyz>
    date: Mon, 3 Dec 2018 09:27:35 +0900
    Add PGXS options to control TAP and isolation tests, take two

    The following options are added for extensions:
    - TAP_TESTS, to allow an extention to run TAP tests which are the ones
    present in t/*.pl.  A subset of tests can always be run with the
    existing PROVE_TESTS for developers.
    - ISOLATION, to define a list of isolation tests.
    - ISOLATION_OPTS, to pass custom options to isolation_tester.

    A couple of custom Makefile rules have been accumulated across the tree
    to cover the lack of facility in PGXS for a couple of releases when
    using those test suites, which are all now replaced with the new flags,
    without reducing the test coverage.  Note that tests of contrib/bloom/
    are not enabled yet, as those are proving unstable in the buildfarm.

    Author: Michael Paquier
    Reviewed-by: Adam Berlin, Álvaro Herrera, Tom Lane, Nikolay Shaplov,
    Arthur Zakirov
    Discussion: https://postgr.es/m/20180906014849.GG2726@paquier.xyz

This is similar rather to the existing REGRESS and REGRESS\_OPTS which
allow to respectively list a set of regression tests and pass down
additional options to pg\_regress (like a custom configuration file).
When it comes to REGRESS, input files need to be listed in sql/ and
expected output files are present in expected/, with items listed without
a dedicated ".sql" suffix.

The new options ISOLATION and ISOLATION\_OPTS added in PostgreSQL 12 are
similar to REGRESS and REGRESS\_OPTS, except that they can be used to
define a set of tests to stress the behavior of concurrent sessions, for
example for locking checks across commands, etc.  PostgreSQL includes in
its core tree the main set of isolation tests in src/test/isolation/,
and has also a couple of modules with their own custom set:

  * contrib/test_decoding/
  * src/test/modules/snapshot\_too\_old/

To add such tests, a set of tests suffixed with ".spec" need to be added
to a subdirectory of the module called specs/, matching with entries listed
in ISOLATION without the suffix.  Output files are listed in an subdirectory
called expected/, suffixed with ".out" similarly to tests listed in REGRESS.

Another new option available is called TAP_TESTS, which allows a module to
define if TAP tests need to be run.  This is described extensively in the
[documentation](https://www.postgresql.org/docs/devel/regress-tap.html) as
a facility which uses the Perl TAP tools.  All the tests present in the
subdirectory t/ and using ".pl" as suffix will be run.  Note that a subset
of tests can be enforced with the variable PROVE_FLAGS, which is useful
for development purposes.  Some modules use it in the core code:

  * contrib/oid2name/
  * contrib/vacuumlo/
  * src/test/modules/brin/
  * src/test/modules/commit_ts/
  * src/test/modules/test\_pg\_dump/

The main advantage of those switches is to avoid custom rules in one's
extension Makefile.  Here is for example what has been used by many modules,
including a couple of tools that I have developed and/or now maintain:

    check:
        $(prove_check)

    installcheck:
        $(prove_installcheck)

One of the main benefits is a huge cleanup of all the makefiles included
in PostgreSQL core code which have accumulated custom rules across many
releases, as well as better long-term maintenance of all in-core as well
as out-of-core modules which depend on PGXS, so that is really a nice
addition for the project.
