---
author: Michael Paquier
date: 2012-08-09 01:04:28+00:00
layout: page
type: page
slug: explore-config-files
title: PostgreSQL - Parse Configuration Files
tags:
- postgres
- postgresql
- database
- open source
- configuration
- explore
- fdw
- file
- file_fdw
- extract
- parse
---
It may be possible that you do not have access to the configuration files of a PostgreSQL server due to some administration permission issues. There are several options available to get a look at the configuration files without having a session on server. There are configuration parameters indicating the place of each configuration file, called config\_file, hba\_file and ident\_file.

    postgres=# show config_file;
                    config_file                
    -------------------------------------------
     $HOME/pgsql/master/postgresql.conf
    (1 row)
    postgres=# show ident_file;
                   ident_file                
    -----------------------------------------
     $HOME/pgsql/master/pg_ident.conf
    (1 row)
    postgres=# show hba_file;
                   hba_file                
    ---------------------------------------
     $HOME/pgsql/master/pg_hba.conf
    (1 row)

You can also directly read the file content with queries like:

    WITH f(name) AS (VALUES('pg_hba.conf'))
    SELECT pg_catalog.pg_read_file(name, 0, (pg_catalog.pg_stat_file(name)).size) FROM f;
    SELECT * from pg_catalog.pg_read_file('pg_hba.conf');
