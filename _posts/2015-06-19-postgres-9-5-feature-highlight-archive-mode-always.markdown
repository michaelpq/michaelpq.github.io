---
author: Michael Paquier
OBlastmod: 2015-06-19
date: 2015-06-19 7:28:11+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-archive-mode-always
title: 'Postgres 9.5 feature highlight: archive_mode = always'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- highlight
- feature
- 9.5
- archive
- mode
- always
- master
- standby
- node
- bandwidth
- strategy

---

After seeing an email on [pgsql-general]
(http://www.postgresql.org/message-id/CANkGpBs7qgAkgQ-OPZY0EsaM6+WUE5MgpyeHCGo_eOQ7tJVyyg@mail.gmail.com)
about a user willing to be able to archive WAL from a standby to store
them locally and to save bandwidth by only receiving the WAL segments
through a WAL stream, let's talk about a new feature of Postgres 9.5
that will introduce exactly what this user was looking for, as known
as being able to archive WAL from a standby to have more complicated
archiving strategies. This feature has been introduced by this commit:

    commit: ffd37740ee6fcd434416ec0c5461f7040e0a11de
    author: Heikki Linnakangas <heikki.linnakangas@iki.fi>
    date: Fri, 15 May 2015 18:55:24 +0300
    Add archive_mode='always' option.

    In 'always' mode, the standby independently archives all files it receives
    from the primary.

    Original patch by Fujii Masao, docs and review by me.

As mentioned in the commit message, setting archive_mode = 'always' will
make a standby receiving WAL from a primary server archive the segments
whose reception has been completed. While it can be interesting for even
a set of nodes running on the same host to have each of them archive
independently WAL segments on different partitions, this becomes more
interesting when nodes are on separate hosts to be able for example to
reduce the bandwidth usage as the bandwidth necessary to archive the WAL
segments on the standby host is directly included in the WAL stream that
a standby gets from its root node, saving resources at the same time.

Let's have a look at how this actually works with a simple set of nodes,
one master and one standby running on the same host, listening respectively
to ports 5432 and 5433 for example. Each node runs the following archiving
configuration:

    $ psql -At -c 'show archive_command' -p 5432
    cp -i %p /path/to/archive/5432/%f.master
    $ psql -At -c 'show archive_command' -p 5433
    cp -i %p /path/to/archive/5432/%f.standby
    $ psql -At -c 'show archive_mode' -p 5432
    always
    $ psql -At -c 'show archive_mode' -p 5433
    always

So with that, both the standby and its primary node will archive their
WAL segments once they are considered as complete. And when enforcing a
switch to the next segment like that:

    $ cd /path/to/archive && ls -l
    total 229384
    -rw-------  1 michael  staff    16M Jun 19 16:06 000000010000000000000001.master
    -rw-------  1 michael  staff   302B Jun 19 16:06 000000010000000000000002.00000028.backup
    -rw-------  1 michael  staff    16M Jun 19 16:06 000000010000000000000002.master
    -rw-------  1 michael  staff    16M Jun 19 16:06 000000010000000000000002.standby
    -rw-------  1 michael  staff    16M Jun 19 16:07 000000010000000000000003.master
    -rw-------  1 michael  staff    16M Jun 19 16:07 000000010000000000000003.standby
    $ psql -At -c 'SELECT pg_switch_xlog()' -p 5432
    0/40001C8

The new segments have been both archived from the standby and the master,
and they are identical:

    $ cd /path/to/archive && ls -l
    total 229384
    -rw-------  1 michael  staff    16M Jun 19 16:06 000000010000000000000001.master
    -rw-------  1 michael  staff   302B Jun 19 16:06 000000010000000000000002.00000028.backup
    -rw-------  1 michael  staff    16M Jun 19 16:06 000000010000000000000002.master
    -rw-------  1 michael  staff    16M Jun 19 16:06 000000010000000000000002.standby
    -rw-------  1 michael  staff    16M Jun 19 16:07 000000010000000000000003.master
    -rw-------  1 michael  staff    16M Jun 19 16:07 000000010000000000000003.standby
    -rw-------  1 michael  staff    16M Jun 19 16:12 000000010000000000000004.master
    -rw-------  1 michael  staff    16M Jun 19 16:12 000000010000000000000004.standby
    $ [[ `md5 -q 000000010000000000000004.master` == \
         `md5 -q 000000010000000000000004.standby` ]] && \
      echo equal || echo not-equal
    equal

Have fun with that.
