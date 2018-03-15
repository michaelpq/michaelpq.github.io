---
author: Michael Paquier
lastmod: 2012-08-01
date: 2012-08-01 00:33:22+00:00
layout: post
type: post
slug: code-evolution-between-postgres-9-1-and-9-2
title: Code evolution between Postgres 9.1 and 9.2
categories:
- PostgreSQL-2
tags:
- 9.1
- 9.2 branch
- cluster
- code evolution
- maintenance
- master
- pgxc
- postgres
- postgres-xc
- postgresql
- release
- stable
---

For the last couple of days I have been working on merging the code of [Postgres-XC](http://sourceforge.net/projects/postgres-xc/) from 9.1 to 9.2. The release 1.0 of XC has been based on 9.1, but it is time to move forward and steal the latest PostgreSQL amazing features :). The plan was to plug in the code of XC up to the intersection of PostgreSQL master branch and 9.2 stable branch, pretty interesting for two things:
	
  * Possibility to create stable branches of Postgres-XC based on the 9.2 stable branch of Postgres	
  * Preserve the code for merges with future PostgreSQL releases

So the code stays in sync with the latest stable branch of Postgres and the master branch.

However, after this small regression... It has been honestly an interesting experience, allowing me to have a look at the latest evolutions inside PostgreSQL itself between 9.1 and 9.2, and I picked up a couple of items that changed since last year. This list is of course not a complete one, as it results from all the merge conflicts I have seen between Postgres-XC code and PostgreSQL code, so I might not have seen everything on board. More a memo than anything else, perhaps this will help some hackers when upgrading their own code and features not in core.
	
  * Separation of PGPROC into PGXACT and PGPROC. The new structure PGXACT contains information related to vacuum and snapshot. This really improves the performance for multi-core
  * Removal of RecentGlobalXmin from snapshot data
  * Addition of clause IF EXISTS in several DDL. You should avoid to use missing\_ok in RangeVarGetRelid to false in order to get correct error messages
  * Check if a table column has a dependency with a rule and do not drop it when it is the case
  * Return messages presenting details of tuple data back to client for tuples that failed to satisfy a constraint
  * Removal of inner\_plan and outer\_plan from deparse\_namespace
  * Creation of a new utility command for CREATE TABLE AS, called CreateTableAsStmt. Before CTAS was included in Query with intoClause, this clause has been removed and now both SELECT INTO and CREATE TABLE AS are transformed into this utility at query analysis. Honestly this is cleaner like this
  * Management of cached plans largely modified. In short, the way plans cached have been changed in plancache.c has been really refactored
  * Management of tuple sorting in tuplesort.c. SortSupport is now used instead of ScanKeys
  * Use of PlannerInfo instead of PlannerGlobal when setting references in a plan
  * Setup of parameters in a planner path (see pathnode.c)
  * Modifications for RangeVarGetRelid functions in namespace.h. The calling protocol is extended with no-wait and callback options
  * New functionalities in var.c to pull out Var clauses for a given varno. Some of the APIs were already implemented in XC, but better to use the stuff from core
  * DROP of TRIGGER and RULES is now groupped with DropStmt, before it was under the banner DropPropertyStmt

Of course this list is far from showing all the things done in Postgres for 1 year... This is just the top of the iceberg.
