---
author: Michael Paquier
comments: true
lastmod: 2012-03-02
date: 2012-03-02 09:19:01+00:00
layout: post
type: post
slug: report-on-pgcon-japan-2012
title: Report on PgCon Japan 2012
categories:
- PostgreSQL-2
tags:
- conference
- database
- japan
- jpug
- migration
- pgcon
- pgxc
- postgres
- postgres-xc
- postgresql
- tokyo
---

A PostgreSQL conference has happened on the 24th of February in Tokyo, Shinagawa, event organized by [JPUG (Japanese PostgreSQL user's group)](http://www.postgresql.jp/). You can go to [this page](http://www.postgresql.jp/events/pgcon2012) where all the materials of presentations are available. Most of the presentations were in Japanese, but the following ones were in English (links provided to materials if possible):

  * How a large organisation moved its critical application toward PostgreSQL, By Philippe Beaudoin, special quest of the event.
  * [An overview of PostgreSQL 9.2](http://www.postgresql.jp/events/pgcon2012/docs/k2.pdf), by Robert Haas
  * [Postgres-XC, toward 1.0](http://www.postgresql.jp/events/pgcon2012/docs/a2.pdf), well if you are on this blog you might already know who did it and the content of this material

As a main summary of the events, I was really surprised by the number of participants, 250 people came from Tokyo and even farer. This resulted in the bad impression that the organizers did not really manage clearly this event because for each presentation, the rooms were completely crowded and there were always people standing up. It is good to see that PostgreSQL has so much success in Japan.

Participating at this event both as translator for Philippe (French -> Japanese) and as a presenter of Postgres-XC, well, to be honest, it has been a pretty busy day. I don't really know if I did a good translation, but at least I got good feedback from the public. As a first experience, it was a nice one.

So, a couple of words about the presentations at the conference I saw. As the official translator of the presentation of the first Keynote, I had some time to understand the presentation of Philippe. And I believe it is really a great example of a success-story using PostgreSQL. The migration project lasted 18 months, for a team of more or less 10 engineers. So when you do such a migration, what are the points you should really care about? Here is what I understood from this presentation:

  * Do a deep study of what are the modifications necessary to the table structures to make a migration without problems. Postgres supports a lot of types, but still you never know
  * Build a prototype to limit the risk when performing a migration
  * Do huge and long acceptance test. PostgreSQL is robust and is famous for that, so you should more worry about the interface you put in place for the migration and the new interface between postgres and the old frontend application.
  * Tests, tests, and tests... And more tests. It is essential to accumulate confidence by overdoing tests.
  * Do not underestimate the impact of migration on external tools: monitoring, batch applications or query modifications

This was really a productive presentation.

Then there was the presentation of Robert, about all the new features of 9.2. To be honest, this is going to be a performance release. Robert has worked a lot on improving performance on multiple core machines. He has shown in this aim a couple of graphs showing results with pgbench. A guy in the public has promised him access to a 64-core machine to do some tests on more powerful machines. So, there was nothing really surprising in this presentation, people following the hackers mailing list or the commits in GIT are already updated on the subject. However, here is a small list of features new in 9.2 presented by Robert:

  * Scalability performance
  * JSON type is available in 9.2, basic support, there are still bugs in it but still nice
  * Index only scans
  * [Cascading replication](/postgresql-2/cascading-replication-in-postgresql/)
  * Reduction of power consumption (nice for hosting services)

This post is getting long, but here is some feedback about the presentation I gave about Postgres-XC. I got the feeling that people are expected a lot from the project (too much??). The public has been very enthusiastic about the technology presented and few people slept this time :). This was a very general presentation showing the policy we try to respect for 1.0 release. Here is a list of the questions I got, well there were a lot of things about failure and HA, nothing really on performance or feature:

  * What to do if you have a 2PC which finishes as non-consistent in cluster, like when a node fails during 2PC? You need to clean up the 2PC info: force commit for transactions partially prepared/committed, abort the transactions partially prepared/aborted, commit the transactions prepared. If you got transactions with abort/commit/prepare status in your cluster => use PITR and fallback.
  * Datanode is a SPOF, how to fix that? You can use internal streaming replication in Postgres. Current code of XC is based on Postgres 9.1.
  * And for GTM? There is a GTM-Standby feature for this purpose.

That was indeed a nice event. A lot of people participated, and organizers are thinking about doing it with more people next year (300~350 perhaps), as more and more people are orienting their business to Open source solutions for Databases in Japan (take that, Or**le!), and PostgreSQL is the world's most advanced open source database, no?

Edit: For those of you who are wondering what about the rest of the conference. This post will be completed by a 2nd presenting 2 high-availability technologies designed in Japan. This report was too long for a single post.
