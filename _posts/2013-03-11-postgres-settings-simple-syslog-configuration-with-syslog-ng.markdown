---
author: Michael Paquier
comments: true
date: 2013-03-11 06:19:48+00:00
layout: post
slug: postgres-settings-simple-syslog-configuration-with-syslog-ng
title: 'Postgres settings: simple syslog configuration with syslog-ng'
wordpress_id: 1740
categories:
- PostgreSQL-2
tags:
- combination
- configuration
- facilty
- linux
- log
- postgres
- postgresql
- server
- setting
- solution
- syslog
- syslog-ng
- systemctl
---

Setting up logging for a PostgreSQL server using syslog on a Linux machine is intuitive especially with logging systems like syslog-ng, you just need to put the correct parameters at the right place.

First, you need to setup the system side, by adding the following settings in /etc/syslog-nd/syslog-nd.conf (or similar, don't hesitate to customize that with your own paths).

    destination postgres { file("/var/log/pgsql"); };
    filter f_postgres { facility(local0); };
    log { source(src); filter(f_postgres); destination(postgres); };

This will send all the logs of postgresql server to /var/log/pgsql. Be sure to combine that with some solution rotating log files to avoid a single file becoming too large... And reload syslog-ng with a command similar to that (varies depending on distribution used, here Archlinux).

    systemctl reload syslog-ng

Then, you need to add those settings in postgresql.conf.

    log_destination = 'syslog' # Can specify multiple destinations
    syslog_facility='LOCAL0'
    syslog_ident='postgres'

Based on the [documentation](http://www.postgresql.org/docs/9.1/static/runtime-config-logging.html#GUC-SYSLOG-FACILITY), syslog\_facility can be set from LOCAL0 to LOCAL7.
Don't forget that you can also specify multiple log destinations. For example when using stderr and syslog at the same time, simply do that:

    log_destination = 'stderr,syslog'

Finally, reload the parameters of server and you are done.

    pg_ctl reload -D $PGDATA

Note that restarting the server is not necessary.
