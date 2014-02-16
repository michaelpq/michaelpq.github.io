---
author: Michael Paquier
date: 2012-08-03 11:43:12+00:00
layout: page
type: page
slug: logging
title: PostgreSQL - Logging
tags:
- postgres
- postgresql
- open source
- database
- settings
- logging
- monitoring
- performance
- pg_log
- csv
- collector
- syslog
---

### General


Logging has little impact on the system, so even large values are OK. Good source of information to find performance bottlenecks and tune the system. Preferential settings for logging information in postgresql.conf. Place where to log, they depend on the system and external tools you are using with your system.

  * syslog
  * standard format to files, you might be using tools for standard formats
  * CVS format to files

Some parameters to use.

    log_destination = 'csvlog'
    log_directory = 'pg_log'
    logging_collector = on
    log_filename = 'postgres-%Y-%m-%d_%H%M%S'
    log_rotation_age = 1d
    log_rotation_size = 1GB
    log_min_duration_statement = 200ms
    log_checkpoints = on
    log_connections = on
    log_disconnections = on
    log_lock_waits = on
    log_temp_files = 0

### syslog

When using syslog-ng, set up those parameters in /etc/syslog-ng/syslog-ng.conf.

    destination postgres { file("/var/log/pgsql"); };
    filter f_postgres { facility(local0); };
    log { source(src); filter(f_postgres); destination(postgres); };

Then set those parameters in postgresql.conf.

    log_destination = 'stderr,syslog' # Can specify multiple destinations
    syslog_facility='LOCAL0'
    syslog_ident='postgres'

Then reload parameters (no restart necessary).

    pg_ctl reload -D $PGDATA
