---
author: Michael Paquier
lastmod: 2011-09-05
date: 2011-09-05 03:47:06+00:00
layout: post
type: post
slug: rpm-building
title: RPM building
categories:
- Linux-2
tags:
- building
- centos
- cpio
- fedora
- file
- linux
- package
- rpm
- rpmbuild
- spec
---

Here is a memo about RPM building in Linux environment.
First is necessary an RPM-based distribution. The most famous are Fedora and CentOS.

Let's suppose you want to build your RPMs in the folder $RPMREPO.
You need first the correct folder tree for package creation.

    mkdir $RPMREPO
    cp -r /usr/src/redhat/* $RPMREPO

Then what is necessary is a spec file (Ex: spec\_file.spec). It contains all the directives necessary to create the package.
You may find examples of spec files in RedHat SVN repositories like the one of [PostgreSQL 9.0 package](http://postgres-xc.git.sourceforge.net/git/gitweb.cgi?p=postgres-xc/pgxcrpm;a=summary).
With a spec file, you may need a PAM file (Ex: file.pam), containing data like:

    #%PAM-1.0
    auth include password-auth
    account include password-auth

Don't forget that you also need a tarball (Ex: foo.tar.gz) or something equivalent containing the code.
Then copy the PAM file and the tarball inside $RPMREPO/SOURCES.

    cp file.pam foo.tar.gz $RPMREPO/SOURCES

Copy the spec file to the correct folder.
    cp spec_file.spec $RPMREPO/SPECS

Before building an RPM, it is necessary to set a file called .rpmmacros located in $HOME directory.

    echo "%_topdir $RPMREPO" > $HOME/.rpmmacros

Then you can create the RPM with this command, assuming spec, pam and tarball files are correct.

    rpmbuild -ba spec_file.spec

If no error occurred, SRPM file is located in $RPMREPO/SRPMS, RPM packages are located in $RPMREPO/RPMS/x86_64.

Here are some additional useful commands.
You can also build a RPM package from a SRPM file.

    rpmbuild --rebuild $SRPM_FILE

Check content of an RPM file.

    rpm -qpl $RPM_FILE

Export files of an RPM package.

    rpm2cpio $RPM_FILE | cpio -idv
