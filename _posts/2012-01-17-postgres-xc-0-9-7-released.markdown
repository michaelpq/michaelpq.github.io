---
author: Michael Paquier
comments: true
date: 2012-01-17 02:46:41+00:00
layout: post
slug: postgres-xc-0-9-7-released
title: Postgres-XC 0.9.7 released
wordpress_id: 737
categories:
- PostgreSQL-2
tags:
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
- sql
- update
---

The release of Postgres-XC 0.9.7 has been done in Source Forge and in GIT.
Source forge page is [here](https://sourceforge.net/projects/postgres-xc/).
The source tarball and manuals are available [here](https://sourceforge.net/projects/postgres-xc/files/Version_0.9.7/).

Postgres-XC 0.9.7, based on PostgreSQL 9.1, contains a bunch of new features:

  * SELECT INTO/CREATE TABLE AS
  * INSERT SELECT complete support
  * Node subsets and sub clusters (data of table distributed on a portion of nodes)
  * Cluster node management with SQL and catalog extensions
  * Dynamic reload of pool connection information
  * Window functions
  * DML remote planning (partial expression push-down)
  * DEFAULT values (non-shippable expressions: volatile functions, etc.) => Use of DEFAULT nextval('seq') available.
  * GTM Standby synchronous, asynchronous recovery

Compared to Postgres-XC 0.9.6, in 0.9.7 the cluster setting is mainly SQL-based and does not use GUC params anymore. So be sure to read the Install manual before creating a cluster.
HTML documentation and man pages are also incorporated in the downloadable tarball, and the reference PDF document is built from the same SGML source.

The code is also available on GIT:

    git://postgres-xc.git.sourceforge.net/gitroot/postgres-xc/postgres-xc

A new maintenance branch called XC0_9_7_PG9_1 only for 0.9.7.
