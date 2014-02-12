---
author: Michael Paquier
comments: true
date: 2013-07-02 07:54:18+00:00
layout: post
slug: postgres-9-3-feature-highlight-data-checksums
title: 'Postgres 9.3 feature highlight: Data Checksums'
wordpress_id: 2006
categories:
- PostgreSQL-2
tags:
- '9.3'
- calculation
- checksum
- data
- database
- feature
- highlight
- loss
- open source
- performance
- postgres
- postgresql
- protection
- wal
---

Data checksums is a new feature introduced in PostgreSQL 9.3, adding a new level of checksum to protect data from disk and I/O corruption, controlled directly by the database server. This has been introduced by the commit below.

    commit 96ef3b8ff1cf1950e897fd2f766d4bd9ef0d5d56
    Author: Simon Riggs <simon@2ndQuadrant.com>
    Date:   Fri Mar 22 13:54:07 2013 +0000
    
    Allow I/O reliability checks using 16-bit checksums
    
    Checksums are set immediately prior to flush out of shared buffers
    and checked when pages are read in again. Hint bit setting will
    require full page write when block is dirtied, which causes various
    infrastructure changes. Extensive comments, docs and README.
    
    WARNING message thrown if checksum fails on non-all zeroes page;
    ERROR thrown but can be disabled with ignore_checksum_failure = on.
    
    Feature enabled by an initdb option, since transition from option off
    to option on is long and complex and has not yet been implemented.
    Default is not to use checksums.
    
    Checksum used is WAL CRC-32 truncated to 16-bits.
    
    Simon Riggs, Jeff Davis, Greg Smith
    Wide input and assistance from many community members. Thank you.

This feature can only be enabled at server initialization by using the newly-added option -k/--data-checksums of initdb. If enabled, checksums are calculated for each data page. The detection of a checksum failure will cause an error when reading data and will abort the transaction currently running. So, this brings additional control for the detection of an I/O or hardware problem directly at the level of the database server.

There are a couple of things to be aware when using this feature though. First, using checksums has a cost in performance as it introduces extra calculations for each data page (8kB by default), so be aware of the tradeoff between data security and performance when using it.

Also, this feature introduces a new GUC parameter called ignore\_checksum\_failure allowing to skip a checksum error and return to the client a warning instead of an error if a failure is found. Be aware that a checksum failure means that the data on disk is corrupted, so ignoring such errors might lead to data corruption propagation or even crashes. Hence, I would personally recommend not to set that parameter to true if checksums are enabled.

The checksum algorithm used in 9.3 is CRC32 reduced to 16 bits, you can have a look at PageCalcChecksum16 in bufpage.c for more details. Future versions of PostgreSQL will probably support some other types of algorithms in the future as necessary infrastructure has been added in pg\_controldata for this purpose.

Note also that pg\_upgrade will fail if the cluster to-be-upgraded and the new cluster do not use the same checksum algorithm. If the algorithms used are different between the old and new clusters, pg\_upgrade will fail with the following incompatibility error:

    old and new pg_controldata checksum versions are invalid or do not match
