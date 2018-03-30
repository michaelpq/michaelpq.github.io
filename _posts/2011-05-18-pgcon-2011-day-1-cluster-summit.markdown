---
author: Michael Paquier
lastmod: 2011-05-18
date: 2011-05-18 15:22:21+00:00
layout: post
type: post
slug: pgcon-2011-day-1-cluster-summit
title: 'PGCon 2011, Day 1 - Cluster summit'
categories:
- PostgreSQL-2
tags:
- pgpool
- postgres
- postgres-xc
- postgresql
- product
- conference

---

Currently being in Ottawa for PostgreSQL conference, I had the chance to participate to meeting gathering all most of the programmers and maintainers of PostgreSQL-based cluster products.
The meeting has been held on May 17th 2011, at Desmarais building of Ottawa university. 27 people have participated in the debates, with Josh Berkus as chairman.

All the participants being involved in cluster projects have been invited to present in a couple of minutes the situation of their projects. This made the morning session.
A total of 7 projects had their status presented: Slony, PGPool-II, Grid SQL, PostgresXC (myself), Bucardo, Skytools, Binary Replication, Mammoth.
Without entering in details, here are the main points that caught my attention:
	
  * About Skytools, its version 3.0 contains generic replication queue (implemented since 2.1), cascade replication and plug-in functionalities which allows to change partitioning keys. They have also implemented multi-master that can merge row updates among several databases. 3.0 will be released to public within this year with its code open. Nothing is known yet about Skytools 3.1 as Microsoft bought Skype recently.	
  * Streaming replication has shown a lot of progress. Synchronous replication has been implemented in Postgres 9.1 and makes the whole system really valuable commercially.
  * GridSQL is not dead. Even if EnterpriseDB has decided not to support it anymore, a fork of it called Stado has been created.	
  * Development of Mammoth has been stopped. Streaming replication in PostgreSQL 9.0 has made it hard to maintain.
  * Postgres-XC had good return from the audience. It has been referenced more than other cluster for its multi-master capacities and external XID/snapshot feed features.
  * All the projects presented base their data distribution on replication, except Skytools, Stado and Postgres-XC

Afternoon session was focused on talks about [Cluster features](http://wiki.postgresql.org/wiki/ClusterFeatures). This list of features has been decided during the first cluster summit that was held in Tokyo on November 2009.
The main goal of the afternoon session was to first update the status of each feature depending on the projects that have made progress on it.
Then, about how to keep the effort on this feature, to decide which cluster team could do what, and when they could do it, if it is not done yet.
Finally, to hold breakout session on some topics that may need deeper conversations.

I have personally seen a lot of progress in this afternoon session compared to what has been decided during the first cluster summit in Tokyo 1 year and a half ago.
The list of features that could to be necessary has been cleaned up, more finely defined, and the level of priority of each feature has been reorganized.
Also all the participants have decided who is going to work on what, and then report his progress during the next cluster summit.

Here are the main progresses I think are valuable (at least as a Postgres-XC developer):

  * Everybody is showing interest in snapshot exporting for parallel query. It definitely should be proposed to PostgreSQL community and included in core. Postgres-XC team looks to be the best candidate for a proposal.	
  * Global conflict resolution and detection. This is a common problem that is found in clusters. At the current state cluster based their lock and wait-for graph analysis on local and no real global mechanism has been defined. This really needs investigation and priority should be set as higher than currently.
  * Some people have shown some interest in the idea to provide a database lock system. Now clusters have no way to check if a database creation/drop has been safely executed in the cluster.  Let's think about that as a 2PC-like mechanism, but as database drop/creation is not transactional, I call that a locking system. The idea of this mechanism is to block the use of a database by dropping stopping new sessions, new connections, and wait for current connections to be cut in soft mode. In force mode, connections could be forced to be dropped. A definition is available [here](http://wiki.postgresql.org/wiki/Lock_database).

Then came the breakout sessions, two have been necessary for DDL triggers and parser API.
I personally participated in parser API session with pgpool teams.
Even if it looks there has been excellent improvements on DDL triggers, I have personally been disappointed by the parser API discussion.
The point was to try to define external APIs of Postgres to allow external applications (here PGpool, pgadmin, let application try to determine of query is read-only).
However, the parser/planner/analyzer tree of Postgres is a structure which changes at each major release and such APIs may represent a high cost in maintenance for applications depending on it. Is it really worth doing it?

In conclusion, progress on cluster cooperation is following a good shape. It has been a productive day and let's hope that people will gather more than every 2 years to talk about the progress being done on each project.
In case you are looking for details, minutes are available [here](http://wiki.postgresql.org/wiki/PgCon2011CanadaClusterSummit).

