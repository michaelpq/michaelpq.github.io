---
author: Michael Paquier
date: 2012-08-03 12:24:43+00:00
layout: page
type: page
slug: maintenance
title: PostgreSQL - Maintenance
tags:
- postgres
- postgresql
- database
- open source
- maintenance
- vacuum
- clean
- data
- performance
- streaming
- archive
- recovery
- monitoring
---
Here are some guidelines giving recommendations for the maintenance of a PostgreSQL server.

  1. Monitoring
  2. Backup
  3. Recovery
  4. Pitfalls

### 1. Monitoring

It is always important to monitor PostgreSQL. The things that should be monitored:

  * Disk space and system load
  * Memory and I/O
  * 1 minute bins

### 2. Backup

A backup can be easily performed with pg\_dump. it is useful as it has a low impact on the database by making a copy of the database. However this becomes impractical if database is bigger than a couple of GB.

Another solution is the use of streaming replication. Best solution for large databases and easy to set up. This maintains an exact copy of the database on another server or another data folder on same host. This is only a database-level guard, if application fails, you need something else for that application. Slave nodes (replicated nodes) can be used for read queries to leverage read on a cluster. You might be getting query cancellations, so in this case increase max\_standby\_streaming\_delay to 200% of the longest query execution time. It is possible to take a dump of a replica. Streaming replication is an all-or-nothing model.

### 3. Recovery

PostgreSQL is based on WAL (write-ahead log), which are records about what is happening on the database. A recovery consists roughly in replaying those records at instance restart.
It is important to maintain a set of base backups and WAL segments on a (remote) server. It can be used for point-in-time recovery in case of an application (or DBA) failure. This is more complex to setup by it is worth the move, however this cannot be used alongside streaming replication.

### 4. Pitfalls

#### Encoding

A database encoding is defined at database creation. The defaults are perhaps hot what you are looking for. You should use UTF-8 encoding, and sometimes C-collate makes sense.

#### Schema migration

Addition of a column on a large table. PostgreSQL needs an exclusive lock on the table and rewrites it completely tuple by tuple in this case. So if you add a column, the table will not be accessible to other sessions for a long time if your table is really huge. Avoid also to do things like watching production system fall over and go boom as PostgreSQL appears to freeze... In case of schema migrations, as mentioned before, all modifications to a table take an exclusive lock on that table while the modification is being done. If you add or delete a column with a default value, the table will be rewritten. This can take a looong tim, and table data will be inaccessible to the other sessions. However there are solutions for that.

  * Create columns as not NOT NULL, then add constraint later once field is filled. This takes a lock of course, but a faster one...
  * Create a new table, and copy values into it. Old table can be read, not written.

#### Idle sessions

Those are sessions doing absolutely nothing, waiting for the application some action. You should avoid that, your session is wasted.

#### VACUUM FREEZE

Once in a long while, PostgreSQL needs to scan (and sometimes write) every table and this can be a big surprise. Once every few months, pick a (very) slack period and do a VACUUM FREEZE. This is important to clean up completely your database from time to time.
