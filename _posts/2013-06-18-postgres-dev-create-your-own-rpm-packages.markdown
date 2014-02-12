---
author: Michael Paquier
comments: true
date: 2013-06-18 05:14:23+00:00
layout: post
slug: postgres-dev-create-your-own-rpm-packages
title: 'Postgres dev: create your own RPM packages'
wordpress_id: 1973
categories:
- PostgreSQL-2
tags:
- binary
- build
- compilation
- deployment
- distribution
- extension
- fedora
- module
- option
- package
- postgres
- rhel
- rpm
---

Creating RPM packages for your own needs can be quite an adventure the first time, especially with a code base as complex as Postgres considering all the submodules, options and extensions that the core code can come up with. But thanks to all the work done by the community, the building process is quite easy.

First, be sure to get the RPM specs from the official RPM repository.

    git svn clone http://svn.pgrpms.org/repo/rpm/redhat

The spec repository has a structure depending on the version of postgresql, the Linux distribution on which the RPMs are based, and the package that needs to be built. There is also a common part called common/ where are defined all the rules used by all the Makefiles of each package, like some rules for calls as rpmbuild.

Depending on the version or the package you want to build, simply move into the dedicated folder:

    cd $VERSION/$PACKAGE_NAME/$DISTRIBUTION

$VERSION should be something like 9.3, $PACKAGE\_NAME named as postgresql, and $DISTRIBUTION be like EL-6 or F-17 depending on the Linux distribution where you want to build the packages.

Then run this command to create the packages.

    make rpm

And you should basically be done... But actually not if your environment lacks some libraries.

You might run into dependency issues.

    error: Failed build dependencies:
        tcl-devel is needed by postgresql93-9.3beta1-4PGDG.rhel6.x86_64
        e2fsprogs-devel is needed by postgresql93-9.3beta1-4PGDG.rhel6.x86_64
        uuid-devel is needed by postgresql93-9.3beta1-4PGDG.rhel6.x86_64

The necessary libraries can be found with the flag BuildRequires in postgresql.spec, and depend on the build options wanted, like ldap or python activation for example. You might not need that many things for your own build though.

The RPM build is also dependent on some files obtained from some external sources, of course the source tarball, but also some pdf documentation always difficult to generate if a particular environment with jade is not set up. The files obtained from external sources can be found with the tags Source$NUM with an URL in the spec file, here is for example what happens in the case of the PDF documentation.

    Source12:        http://www.postgresql.org/files/documentation/pdf/%{majorversion}/%{oname}-%{majorversion}-A4.pdf

When writing this post, the 9.3 beta1 build failed only because of this PDF file not accessible:

    cp -p $HOME/git/rpm/9.3/postgresql/EL-6/postgresql-9.3-A4.pdf .
    cp: cannot stat `$HOME/git/rpm/9.3/postgresql/EL-6/postgresql-9.3-A4.pdf': No such file or directory

Note that you can as well hack a bit the spec to remove this file when generating your RPM, this needs only the removal of 2 lines.

But it was working correctly for 9.2. Note that if you want to even go deeper in the hacking of the spec file, as you might need to adjust the build process to your own environment, be sure to always use a command of that type that will generate the RPMs for you:

    rpmbuild --define "_sourcedir $HOME/rpm/9.2/postgresql/EL-6" \
        --define "_specdir $HOME/rpm/9.2/postgresql/EL-6" \
        --define  "_builddir $HOME/rpm/9.2/postgresql/EL-6" \
        --define "_srcrpmdir $HOME/rpm/9.2/postgresql/EL-6" \
        --define "_rpmdir $HOME/rpm/9.2/postgresql/EL-6" \
        --define "dist .rhel6" -bb "postgresql-9.2.spec"

This is only a command defined in common/Makefile.global, but I think it is good to know that it is the central piece of the build process commanded by the spec file.

Once done, the following RPMs (here for 9.2) will be generated:

  * postgresql92-*.rpm, containing some client binaries (pg\_dump, createdb...)
  * postgresql92-libs-*.rpm, containing some client libraries (expg, libpq, libpgtype)
  * postgresql92-server-*.rpm, containing server side binaries (initdb, postgres...)
  * postgresql92-docs-*.rpm, with the documentation
  * postgresql92-contrib-*.rpm, with all the contrib modules
  * postgresql92-devel-*.rpm, with all the development libs and headers
  * postgresql92-plperl-*.rpm, containing the extension plperl
  * postgresql92-plpython-*.rpm, containing the extension plpython
  * postgresql92-pltcl-*.rpm, containing extension pltcl
  * postgresql92-test-*.rpm, containing all the regression tests
  * postgresql92-debuginfo-*.rpm, heavy package with all the information for debugging purposes

And all you RPMs are here! Be sure to check that their content fits your needs with a command of the type "rpm -qpl".
