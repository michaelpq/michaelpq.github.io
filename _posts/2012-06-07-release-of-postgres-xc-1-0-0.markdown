---
author: Michael Paquier
comments: true
lastmod: 2012-06-07
date: 2012-06-07 07:39:14+00:00
layout: post
type: post
slug: release-of-postgres-xc-1-0-0
title: Release of Postgres-XC 1.0.0
categories:
- PostgreSQL-2
tags:
- '1.0'
- 1.0.0
- cluster
- database
- multi-master
- oracle
- oraclerac
- pgxc
- postgres
- postgres-xc
- postgresql
- release
- scalability
- stable
- symetric
- write-scalable
---

Postgres-XC, read&write-scalable; multi-master symmetric cluster based on PostgreSQL, version 1.0.0 is released.
This project is seen as an open-source alternative to costly products such as OracleRAC. Postgres-XC is based on the code of PostgreSQL, so it can naturally use all its technologies, which are enhaunced to have a shared-nothing multi-master PostgreSQL-based database cluster.

This first stable version is based on PostgreSQL 9.1.4. All the patches in PostgreSQL 9.1 stable branch have been merged up to commit 873d1c1 (1st of June 2012).
This includes the security fix related to pg\_crypto dated of 30th of May.
You can download the source tarball directly from [here](https://sourceforge.net/projects/postgres-xc/files/latest/download)
This tarball contains all the HTML and man documentation.

30 bug fixes have been made since release of beta2, with some notable enhancements:

  * Support for EXTENSION is fixed
  * Stabilization of the use of slave nodes in cluster
  * Fix of a bug related to read-only transactions, improving performance by 15%
  * Support of compilation for MacOSX

About the scalability of this release, Postgres-XC 1.0.0 scales to a factor of 3 when compared to a standalone server PostgreSQL 9.1.3 on 5 nodes using a benchmark called DBT-1.

Compared to version Postgres-XC 0.9.7, the following features have been added:

  * Fast query shipping (FQS), quick identification of expressions in a query that can be pushed down to remote nodes
  * SERIAL types
  * TABLESPACE
  * Utility to clean up 2PC transactions in cluster (pgxc\_clean)
  * Utility for initialization of GTM (global transaction manager, utility called initgtm)
  * Relation-size functions and locking functions
  * Regression stabilization

The documentation of 1.0, including release notes, is available [here](http://postgres-xc.sourceforge.net/docs/1_0/).

The project can be followed on [SourceForge](http://postgres-xc.sourceforge.net/).
And a couple of GIT repositories are used for development:

  * [SourceForge](http://postgres-xc.git.sourceforge.net/git/gitweb.cgi?p=postgres-xc/postgres-xc;a=summary)
  * [Github](http://github.com/postgres-xc/postgres-xc)

The core team is currently working in the addition of new features for the next major release including:

  * Merge with PostgreSQL 9.2
  * Data redistribution functionality, changing table distribution in cluster with a simple ALTER TABLE
  * New functionalities related to online node addition and deletion for a better user experience
  * Triggers
  * Planner improvements
  * Global constraints

The roadmap of the project is located [here](http://postgres-xc.sourceforge.net/) in section Roadmap.

The project is under the same license as PostgreSQL, now managed under a single entity called "Postgres-XC Development Group".
In order to keep in touch with the project, whose development follows the same model as PostgreSQL, you can register to the following mailing lists:

  * postgres-xc-general@lists.sourceforge.net, for general questions. Registration can be done [here](http://lists.sourceforge.net/lists/listinfo/postgres-xc-general)
  * postgres-xc-developers@lists.sourceforge.net. hachers mailing list. Registration can be done [here](http://lists.sourceforge.net/lists/listinfo/postgres-xc-developers)
