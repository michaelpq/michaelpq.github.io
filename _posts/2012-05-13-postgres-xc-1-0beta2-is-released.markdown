---
author: Michael Paquier
lastmod: 2012-05-13
date: 2012-05-13 03:56:17+00:00
layout: post
type: post
slug: postgres-xc-1-0beta2-is-released
title: Postgres-XC 1.0beta2 is released
categories:
- PostgreSQL-2
tags:
- '1.0'
- 1.0beta2
- cluster
- database
- multi-master
- pgxc
- postgres
- postgres-xc
- postgresql
- release
- scalability
- symetric
- write-scalable
---

Postgres-XC, write-scalable multi-master symmetric cluster based on PostgreSQL, version 1.0beta2 has been released.
This beta version is based on PostgreSQL 9.1.3. All the patches in PostgreSQL 9.1 stable branch have been merged up to commit 1c0e678 (4th of May 2012).

You can download the tarball directly from [here](https://sourceforge.net/projects/postgres-xc/files/latest/download).
This tarball contains all the HTML and man documentation.

The following enhancements have been made since release of 1.0beta1:
	
  * Redaction of release notes, summarizing all the features added in Postgres-XC since the creation of the project
  * Support for make world
  * Regressions stabilized (no failures for 139 tests)
  * Fix of more than 50 bugs
  * Merge with stable branch of PostgreSQL 9.1 (600~ commits)

Compared to version Postgres-XC 0.9.7, the following features have been added:

  * Fast query shipping (FQS), quick identification of expressions in a query that can be pushed down to remote nodes 	
  * SERIAL types
  * TABLESPACE
  * Utility to clean up 2PC transactions in cluster (pgxc\_clean)
  * Utility for initialization of GTM (global transaction manager, utility called initgtm)
  * Relation-size functions
  * Regression stabilization

The release notes of 1.0 are directly available [here](http://postgres-xc.sourceforge.net/docs/1_0/release-xc-1-0.html).

The project can be followed on [Source Forge](http://postgres-xc.sourceforge.net/).
And the project uses a couple of GIT repositories for development:
 
  * [SourceForge](http://postgres-xc.git.sourceforge.net/git/gitweb.cgi?p=postgres-xc/postgres-xc;a=summary)
  * [Github](https://github.com/postgres-xc/postgres-xc)

Postgres-XC 1.0beta2 will be used during the Postgres-XC tutorial at PGCon in Ottawa, so be sure to touch this beta version to have an idea of what Postgres-XC is before attending!
