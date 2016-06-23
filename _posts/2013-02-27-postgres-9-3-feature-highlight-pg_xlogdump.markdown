---
author: Michael Paquier
lastmod: 2013-02-27
date: 2013-02-27 01:15:23+00:00
layout: post
type: post
slug: postgres-9-3-feature-highlight-pg_xlogdump
title: 'Postgres 9.3 feature highlight - pg_xlogdump'
categories:
- PostgreSQL-2
tags:
- '9.3'
- data
- database
- debug
- developer
- dump
- educational
- open source
- pg_xlogdump
- postgres
- postgresql
- recovery
- wal
- write ahead log
- xlog
---

pg_xlogdump is a new contrib module introduced in PostgreSQL 9.3 by this commit.

    commit 639ed4e84b7493594860f56b78b25fd113e78fd7
    Author: Alvaro Herrera <alvherre@alvh.no-ip.org>
    Date:   Fri Feb 22 16:46:24 2013 -0300

    Add pg_xlogdump contrib program

    This program relies on rm_desc backend routines and the xlogreader
    infrastructure to emit human-readable rendering of WAL records.

    Author: Andres Freund, with many reworks by Alvaro
    Reviewed (in a much earlier version) by Peter Eisentraut

Mainly useful for educational and debugging purposes, pg\_xlogdump can be used to understand the internals of PostgreSQL by dumping the WAL (Write-ahead log, which is the basic mechanism used by the server for transaction replay during recovery) into a shape humanly readable.

Just a little bit more information about WAL... Its information is stored in files located in pg\_xlog of $PGDATA whose name respect a format name subdivided into 3 sequences of 8 hexa digits defining:

  * Timeline ID
  * Block ID
  * Segment ID

The counter for blocks is incremented once segments are filled.

Postgres includes a couple of functions that can help you to determine in which file is located a given WAL record (pg\_xlogfile\_name) or what is the current WAL position (pg\_current\_xlog\_location).

    michael=# select pg_current_xlog_location();
     pg_current_xlog_location 
    --------------------------
     4A/1799988
    (1 row)
    michael=# select pg_xlogfile_name('4A/1799988');
         pg_xlogfile_name     
    --------------------------
     **00000001**0000004A**00000001**
     (1 row)

Here the server is currently on timeline 1, with a Block ID of 4A and a segment ID of 1. The composition of Block ID + segment ID is a LSN or log sequence number, for example '4A/1799988'. The XLOG files are located in the folder pg\_xlog of $PGDATA. Each file has a size of 16MB, and server switches to a new file once this maximum size is reached or once no new file has been written since a time of archive\_timeout, parameter of postgresql.conf.

After this digression, let's have a look at what this utility can do.
The only mandatory option is to specify a start from where the dump will be taken, by either specifying a start LSN with --start or a start WAL file with commands similar to that.

    pg_xlogdump --start 0/010EA4D0
    pg_xlogdump 000000010000000000000001

If no path is specified to scan the segment files in a given directory, the default is to look if there is a folder called pg\_xlog in current directory and get results from it.
In a dump you will get information like that for each WAL record:

    rmgr: Heap        len (rec/tot):    143/   175, tx:        688, lsn: 0/02010BE8, prev 0/02010BA0, bkp: 0000, desc: insert: rel 1663/16384/11782; tid 41/54`

Each field being in more details:

  * rmgr, the resource manager involved, can be filtered with option -r/--rmgr
  * len, about the length of the record
  * tx, ID of transaction involved with this record, can be filtered with option -x/--xid
  * lsn, log sequence number, including the previous and current lsn, can be filtered with --start and --end.
  * bkp, for the backup block
  * desc, for the description of the action record is doing, and some information related to the relation and page item with which interacts the action

WAL records are divided by resource managers, like database, tablespace, sequence, heap, etc. Based on that you can filter the dump depending on resource manager you want to see. To get a complete list of the resource managers available, simply do that:

    pg_xlogdump --rmgr=list

For example, let's create a sequence on server.

    postgres=# create sequence aas;
    CREATE SEQUENCE

Here is what you dump when filtering  for the resource manager Sequence.

    $ pg_xlogdump --start 0/02000000 -r Sequence
    rmgr: Sequence    len (rec/tot):    158/   190, tx:        688, lsn: 0/02013C18, prev 0/02013B60, bkp: 0000, desc: log: rel 1663/16384/16390

You can then for example dump all the WAL records for this transaction by running a command like that:

    pg_xlogdump --start 0/02000000 -x 688

Only a short introduction of what you can do this module is provided in this post, so for fore details feel free to have a look at [the documentation](http://www.postgresql.org/docs/devel/static/pgxlogdump.html) about the available options and what you can do (and cannot do) with pg\_xlogdump. Honestly I think it is a good tool to understand the internals of Postgres for newcomers.
