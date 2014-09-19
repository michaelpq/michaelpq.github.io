---
author: Michael Paquier
date: 2011-09-12 17:19:05+00:00
layout: page
type: page
slug: conferences
title: Conferences and presentation materials
tags:
- postgresql
- conference
- presentation
- tokyo
- material
- unconference
- bgworker
- pgeu
- europe
- asia
- hacker
- developer
- tutorial
- material
- license
- open source
---

#### Postgres Open 2014: Understanding logical decoding

  * [pdf of PGOpen](/content/materials/20140919_pgopen_logirep.pdf)
  * Place: Chicago, US
  * Date: 2014/09/19
  * Duration: 50~60mins

Presentation about logical decoding and its interactions with replication.
A material for advanced hackers with good Postgres skill and understanding
of the internals of the server, as well as of its external protocols.
Not to be put in the hands of beginners.

#### Postgres Open 2013: Taking advantage of custom background workers

  * [pdf of PGOpen](/content/materials/20130916_pgopen_bgworker.pdf)
  * [pdf of PG-EU 2013](/content/materials/20131029_pgopen_bgworker.pdf)
  * Place: Chicago, US
  * Date: 2013/09/17
  * Place: Dublin, Ireland
  * Date: 2013/10/31, slightly modified slides.
  * Duration: 50~60mins

Presentation about custom background workers, presenting basics of this
new plug-in infrastructure introduced in Postgres 9.3. Several short
examples as well as a coverage of the things to do to have sane bgworkers
in your production environments.

#### SFPUG September 2013: New Postgres 9.3 features, bgworkers and FDW

  * [odp](/content/materials/20130912_sfpug_pg93.odp)
  * Place: San Francisco, US
  * Date: 2013/09/12
  * Duration: 25mins

Short presentation about some new features of postgres_fdw, writable
foreign tables and some basics about background workers.

#### PG-unconf#2 2013: new flavors of pg_top

  * [pdf](/content/materials/20130713_pgunconf_pg_top.pdf)
  * [odp](/content/materials/20130713_pgunconf_pg_top.odp)
  * Place: Tokyo, Japan
  * Date: 2013/07/13
  * Duration: 15mins

Short presentation about the new features of pg_top: database activity,
database I/O and database disk.

#### PG-unconf#2 2013: pg_rewind

  * [pdf](/content/materials/20130713_pgunconf_pg_rewind.pdf)
  * [odp](/content/materials/20130713_pgunconf_pg_rewind.odp)
  * Place: Tokyo, Japan
  * Date: 2013/07/13
  * Duration: 15mins

Short presentation about pg_rewind, a Postgres module able to resync an
old data folder whose WAL has forked with another one, making it possible
to reconnect it to an existing cluster.

#### PG-unconf 2013: custom background workers

  * [pdf](/content/materials/20120216_pgunconf_bgworker.pdf)
  * [odp](/content/materials/20120216_pgunconf_bgworker.odp)
  * Place: Tokyo, Japan
  * Date: 2013/02/16
  * Duration: 15~20mins

Short presentation of custom background workers, new feature of PostgreSQL
2013 allowing to launch custom code loaded by core server in a separate
process living with the server. A "Hello World" example is added in the
presentation to show simply what this feature can do.

#### PGcon 2012: Postgres-XC tutorial

  * [pdf](/content/materials/20120515_PGXC_Tutorial_global.pdf)
  * [odp](/content/materials/20120515_PGXC_Tutorial_global.odp)
  * Place: Paris, France
  * Date: 2012/05/15
  * Duration: 3 hours

Tutorial about Postgres-XC presenting the basics of XC 1.0 in the following
areas: architecture, configuration, planning, HA and community information.
Presentation has been made in cooperation with Koichi Suzuki and Ashutosh
Bapat.

#### Postgres Open 2011: Postgres-XC

  * [pdf](/content/materials/20110916_pgopen_xc.pdf)
  * [odp](/content/materials/20110916_pgopen_xc.odp)
  * Place: Boston, USA
  * Date: 2011/09/16
  * Duration: 40~45 minutes, one hour with questions

Postgres-XC is a write-scalable clustering solution based on PostgreSQL
and uses a synchronized multi-master architecture. Postgres-XC is designed
to make a cluster of multiple nodes seen as one unique transparent database
to external applications. It uses a shared-nothing architecture and
provides write-scalability by distributing data among nodes of the cluster.
It is under PostgreSQL license.

#### PGsession #3/PGCon Japan 2012: Postgres-XC

  * [pdf](/content/materials/20120202_pgsession_xc.pdf)
  * [odp](/content/materials/20120202_pgsession_xc.odp)
  * Place: Paris, France
  * Date: 2012/02/02
  * Place: Tokyo, Japan.
  * Date: 2012/02/24
  * Duration: 45~50 minutes.

This presentation shows the latest highlights of Postgres-XC, focusing on
release 1.0. Explanation about data distribution and node management is
pretty simple and makes understand the basics about Postgres-XC. Slides
are under PostgreSQL license. This presentation has been done once in
Paris (1h30 of presentation, a lot of questions) and in Tokyo the same
month.
