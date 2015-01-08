---
author: Michael Paquier
lastmod: 2011-04-12
date: 2011-04-12 01:28:36+00:00
layout: post
type: post
slug: postgres-xc-0-9-4-manual-and-tar-available
title: Postgres-XC 0.9.4 manual and tar available
categories:
- PostgreSQL-2
tags:
- 0.9.4
- cluster
- database
- git
- manual
- postgres-xc
- postgresq
- postgresql
- release
- repository
- scale out
---

Postgres-XC, write-scalable cluster database manager based on PostgreSQL, version 0.9.4 has been released 1 week ago.
Its manuals have finally been released yesterday in Source Forge.
The latest release of Postgres-XC contains new functionalities and is based on PostgreSQL 9.0.3.

Here is the list of documents released.
	
  * [Install manual	
  * [README](http://sourceforge.net/projects/postgres-xc/files/Version_0.9.4/README/download)
  * [FILES](http://sourceforge.net/projects/postgres-xc/files/Version_0.9.4/FILES/download)
  * [BSD License](http://sourceforge.net/projects/postgres-xc/files/Version_0.9.4/COPYING/download)
  * [tar of Postgres-XC 0.9.4](http://sourceforge.net/projects/postgres-xc/files/Version_0.9.4/pgxc_v0_9_4.tar.gz/download)
  * [SQL Limitations](http://sourceforge.net/projects/postgres-xc/files/Version_0.9.4/PG-XC_SQL_Limitations_v0_9_4.pdf/download)
  * [pgbench tutorial](http://sourceforge.net/projects/postgres-xc/files/Version_0.9.4/PG-XC_pgbench_Tutorial_v0_9_4.pdf/download)
  * [Reference manual](http://sourceforge.net/projects/postgres-xc/files/Version_0.9.4/PG-XC_ReferenceManual_v0_9_4.pdf/download)
  * [Configurator manual](http://sourceforge.net/projects/postgres-xc/files/Version_0.9.4/PG-XC_Configurator_v0_9_4.pdf/download)
  * [DBT-1 Manual](http://sourceforge.net/projects/postgres-xc/files/Version_0.9.4/PG-XC_DBT1_Tutorial_v0_9_4.pdf/download)

You can also now download the manuals from a new GIT repository:
    git clone git://postgres-xc.git.sourceforge.net/gitroot/postgres-xc/pgxcdocs

However to see the diff of the repository, you need to add this configuration to your git config file:
    [diff "odf"]
        textconv = odt2txt`

And those lines to .git/info/attributes.
    *.ods diff=odf
    *.odt diff=odf
    *.odp diff=odf
