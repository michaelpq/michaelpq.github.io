---
author: Michael Paquier
lastmod: 2014-09-14
date: 2014-09-14 14:24:56+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-logging-replication-commands
title: 'Postgres 9.5 feature highlight - Logging of replication commands'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- 9.5
- new
- feature
- replication
- command
- audit
- view
- logging

---

Postgres 9.5 will come up with an additional logging option making possible
to log replication commands that are being received by a node. It has been
introduced by this commit.

    commit: 4ad2a548050fdde07fed93e6c60a4d0a7eba0622
    author: Fujii Masao <fujii@postgresql.org>
    date: Sat, 13 Sep 2014 02:55:45 +0900
    Add GUC to enable logging of replication commands.

    Previously replication commands like IDENTIFY_COMMAND were not logged
    even when log_statements is set to all. Some users who want to audit
    all types of statements were not satisfied with this situation. To
    address the problem, this commit adds new GUC log_replication_commands.
    If it's enabled, all replication commands are logged in the server log.

    There are many ways to allow us to enable that logging. For example,
    we can extend log_statement so that replication commands are logged
    when it's set to all. But per discussion in the community, we reached
    the consensus to add separate GUC for that.

    Reviewed by Ian Barwick, Robert Haas and Heikki Linnakangas.

The new parameter is called log\_replication\_commands and needs to be set
in postgresql.conf. Default is off to not log this new information that may
surprise existing users after an upgrade to 9.5 and newer versions. And
actually replication commands received by a node were already logged at
DEBUG1 level by the server. A last thing to note is that if
log\_replication\_commands is enabled, all the commands will be printed
as LOG and not as DEBUG1, which is kept for backward-compatibility
purposes.

Now, a server enabling this logging mode...

    $ psql -At -c 'show log_replication_commands'
    on

... Is able to show replication commands in LOG mode. Here is for example
the set of commands set by a standby starting up:

    LOG:  received replication command: IDENTIFY_SYSTEM
    LOG:  received replication command: START_REPLICATION 0/3000000 TIMELINE 1

This will certainly help utilities and users running audit for replication,
so looking forward to see log parsing tools like [pgbadger]
(https://github.com/dalibo/pgbadger) make some nice outputs using this
information.
