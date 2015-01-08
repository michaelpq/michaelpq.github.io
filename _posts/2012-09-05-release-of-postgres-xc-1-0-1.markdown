---
author: Michael Paquier
lastmod: 2012-09-05
date: 2012-09-05 05:29:19+00:00
layout: post
type: post
slug: release-of-postgres-xc-1-0-1
title: Release of Postgres-XC 1.0.1
categories:
- PostgreSQL-2
tags:
- 1.0.1
- cluster
- database
- open source
- oracle rac
- parallelize
- pg
- pgxc
- postgres
- postgres-xc
- postgresql
- query
- read
- release
- scalable
- write
---

Postgres-XC, read/write-scalable multi-master symmetric cluster based on PostgreSQL, version 1.0.1 has been released today.

This minor release is based on the latest PostgreSQL 9.1.5+alpha, meaning that all the patches in PostgreSQL 9.1 stable branch have been merged up to commit d10ddf4 (3rd of September 2012).

You can download the source tarball directly from [here](http://sourceforge.net/projects/postgres-xc/files/latest/download).
Like PostgreSQL, this tarball contains all the HTML and man documentation.

The documentation of 1.0, including release notes, is available [here](http://postgres-xc.sourceforge.net/docs/1_0/).

Around 20 bugs have been fixed since 1.0.0, with in particular those fixes:
	
  * Applications like pgadmin had problems to connect to Postgres-XC servers	
  * Drop of sequence was not managed correctly when its database was dropped

You can find all the details in the release notes [here](http://postgres-xc.sourceforge.net/docs/1_0/release-xc-1-0-1.html).

The project can be followed on [Source Forge](http://postgres-xc.sourceforge.net/):
And a couple of GIT repositories are used for development:

  * [SourceForge](http://postgres-xc.git.sourceforge.net/git/gitweb.cgi?p=postgres-xc/postgres-xc;a=summary)	
  * [Github](https://github.com/postgres-xc/postgres-xc)
  * Twitter: @PostgresXCBot, bot giving tweets about the commits in Postgres-XC GIT repository

The project members are currently working hard on the next version of Postgres-XC that will include those features:
	
  * triggers (being implemented)	
  * Merge with PostgreSQL 9.2 code (already committed)
  * RETURNING, WHERE CURRENT OF (being implemented)
  * Insure consistency of utilities that cannot run inside transaction block (ex: CREATE DATABASE safely insured in multiple nodes, being implemented)
  * Change table distribution type with ALTER TABLE (already committed)
  * Support for cursors (already committed)
  * Stuff related to node addition and deletion
  * and other things...

The project is under the same license as PostgreSQL, and is managed under a single entity called "Postgres-XC Development Group".

Have fun with this stable release.
