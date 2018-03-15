---
author: Michael Paquier
lastmod: 2013-09-23
date: 2013-09-23 09:45:12+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-data-checksum-switch-as-a-guc-parameter
title: 'Postgres 9.4 feature highlight - data checksum switch as a GUC parameter'
categories:
- PostgreSQL-2
tags:
- 9.4
- analysis
- checksum
- control
- corruption
- data
- database
- feature
- guc
- indexes
- new
- open source
- parameter
- postgres
- postgresql
- server
---
Postgres 9.3 has introduced [data checksums](/postgresql-2/postgres-9-3-feature-highlight-data-checksums/) at the data page level, using a CRC-16 algorithm for the checksum calculation.

With 9.3, the only way to check if an existing server has checksums enabled was to have a look at the data folder using pg\_controldata like that...

    $ pg_controldata $PGDATA | grep checksum
    Data page checksum version: 0/1

0 indicates that checksums are disabled, and 1 the opposite. By the way, this is particularly unhandy in the case of a server whose file system cannot be accessed directly.

However, a new GUC parameter has been added in Postgres 9.4 reporting if checksums are enabled on a server, making the user life easier. This allows to check the presence of checksums on a cluster by using normal client applications like psql with a simple SHOW command or by having a look at pg\_settings.

    =# SHOW data_checksums;
     data_checksums
    ----------------
     off
    (1 row)
    =# SELECT name, setting, category FROM pg_settings WHERE name = 'data_checksums';
          name      | setting |    category
    ----------------+---------+----------------
     data_checksums |   off   | Preset Options
    (1 row)

Note this parameter is read-only as checksums can only be set at initdb, and that it is not mentioned in postgresql.conf.
