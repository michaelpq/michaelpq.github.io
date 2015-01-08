---
author: Michael Paquier
lastmod: 2011-04-01
date: 2011-04-01 09:47:26+00:00
layout: post
type: post
slug: postgres-xc-0-9-4-released
title: Postgres-XC 0.9.4 released
categories:
- PostgreSQL-2
tags:
- 0.9.4
- cluster
- database
- open source
- postgres
- postgres-xc
- postgresql
- release
- scale out
- scaling
---

Postgres-XC, the only multi-master scaling out PostgreSQL-based cluster, had its version 0.9.4 released yesterday.

Compared with 0.9.3, what is new?

  * Addition of MULTI-INSERT support
  * Addition of a functionality to clean up pooler connections called CLEAN CONNECTION
  * New distribution function for tables called MODULO, this allows more flexibility when creating tables.
  * Code stabilization, return correct errors for functionalities not yet supported and avoid node crashes
  * Support for regression tests, XC is now able to run regression tests without stopping or crashing. It is just a matter of time to finish the stabilization of the diff in regression tests.
  * Addition of node registration features, an identification protocol for nodes in the cluster
  * Correction of numerous bugs, a total of 140 commits have been made. Each commit fixing bug issues, implementing new features or regression outputs

How to get this code? Simply get it directly from the GIT repository!
    git clone git://postgres-xc.git.sourceforge.net/gitroot/postgres-xc/postgres-xc

tar files will be available soon with all the manuals!
