---
author: Michael Paquier
lastmod: 2012-04-10
date: 2012-04-10 04:38:44+00:00
layout: post
type: post
slug: postgres-xc-1-0beta1-released
title: Postgres-XC 1.0beta1 released
categories:
- PostgreSQL-2
tags:
- 1.0
- beta
- cluster
- database
- delete
- feature
- insert
- node
- pgxc
- postgres
- postgres-xc
- postgresql
- select
- software
- symetric
- trial
- update
---

Postgres-XC, write-scalable multi-master symetric cluster based on PostgreSQL, version XC 1.0beta1 has been released.
This beta version is based on PostgreSQL 9.1beta2, and all the fixes of PostgreSQL 9.1 stable branch will be backported in Postgres-XC 1.0 stabilized version.
It is under PostgreSQL license.

You can download the binary directly from [here](https://sourceforge.net/projects/postgres-xc/files/latest/download).
This tarball includes all the HTML and man documentation.

A PDF file containing all the references is also available here: [Reference PDF](http://sourceforge.net/projects/postgres-xc/files/Version_1.0beta1/PG-XC_ReferenceManual_v1_0beta1.pdf/download).

Compared to version 0.9.7, the following features have been added:

  * Fast query shipping (FQS), quick identification of expressions in a query that can be pushed down to remote nodes
  * SERIAL types
  * TABLESPACE
  * Utility to clean up 2PC transactions in cluster (pgxc\_clean)
  * Utility for initialization of GTM (global transaction manager, utility called initgtm)
  * Relation-size functions
  * Regression stabilization

The project can be followed on [Source Forge](http://postgres-xc.sourceforge.net/).
And we use a couple of GIT repositories for development:

  * [SourceForge GIT](http://postgres-xc.git.sourceforge.net/git/gitweb.cgi?p=postgres-xc/postgres-xc;a=summary)
  * [Github](https://github.com/postgres-xc/postgres-xc)

Postgres-XC tutorial at PGCon in Ottawa this May will use a 1.0 version, so be sure to touch this beta version to have an idea of what is Postgres-XC before coming!
Since the last release, a special effort has been made on stabilization and performance improvement, but be sure to give your feedback in order to provide a stable 1.0 release for PostgreSQL community.
