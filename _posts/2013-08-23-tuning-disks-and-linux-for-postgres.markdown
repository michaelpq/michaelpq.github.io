---
author: Michael Paquier
lastmod: 2013-08-23
date: 2013-08-23 02:19:18+00:00
layout: post
type: post
slug: tuning-disks-and-linux-for-postgres.markdown
title: 'Tuning disks and Linux for Postgres'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- linux
- tuning

---

Tuning the OS on which is running a database server is important to get good performance for an application. There are many tricks to know when tuning a system, being generally dependent on the application used and the hardware on which the system is running. Here are some general guidelines that you could get inspiration from when tuning your own environment.

First, be sure to have a correct RAID strategy for your disks, depending partially on their type and their numbers, knowing that:

  * RAID0 with a high number of disks increases performance, as well as the risk of data loss
  * RAID1 is good for redundancy for medium workloads, and can provide good performance for read applications
  * RAID5 should be used for large workloads with more than 3 disks. It can also be good for parallel load

Then, about the file system of your disks, the commonly-used ones are ext3, ext4 and xfs. ext3 has reached maturity and is considered as really stable, but it is not as fast as ext4, this last being not considered that stable. A good choice these days is xfs, it is considered as pretty stable and has good performance. Note that it is also going to become [the default file system for the next RHEL distributions](https://www.serverwatch.com/server-news/where-is-red-hat-enterprise-linux-7.html).

Also, when mounting your disks, be sure to always use the option "noatime". This makes the file system not update information of files that have been updated, information that we do not care about for a database server. Be sure to always put your data folder on a separate disk. Separating certain tables highly read or written on dedicated disks, as well as having pg\_xlog on another disk can improve things as well.

The I/O scheduler is also something that can play a role in your application performance. Its value can be found in /sys/block/$DISK\_NAME/queue/scheduler and the scheduler name can be changed like that:

    echo $SCHEDULER > /sys/block/sda/queue/scheduler

$SCHEDULER becoming here "deadline", "noop" or anything wanted. "deadline" can offer good response times with mix of read/write loads and maintains a good throughput.Choose this wisely depending on your hardware though!

As a last tip, remember that Linux platforms come up with a feature call [readahead](https://linux.die.net/man/2/readahead) allowing to put a file's content into page cache instead of disk, making reading this file faster when it is subsequently accessed. This option can be set by using the command called [blockdev](https://linuxcommand.org/man_pages/blockdev8.html) with the options -getra or -setra to either get or set the read-ahead value. In this case what is set is the number of 512 byte sectors on which readahead will be performed. On most of Linux distributions, it is set on a low value, commonly in a range of values of 256~1024 (128kB~512kB). However a higher value can really improve sequential scans for large tables, as well as index scans on a large number of rows. You should definitely set up readahead to a value higher than the default, and adapt it to your application. Start up with 4096 and see the results! Besides, be aware that values higher than 16MB (32768 for 512 byte sectors) do not show that much performance gain (thanks [Dimitri Fontaine](https://twitter.com/tapoueh) for this info!).
