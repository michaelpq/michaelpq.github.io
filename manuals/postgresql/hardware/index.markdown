---
author: Michael Paquier
date: 2012-08-03 14:14:18+00:00
layout: page
type: page
slug: hardware
title: PostgreSQL - Hardware
tags:
- postgres
- postgresql
- hardware
- settings
- amazon
- cloud
- things
- avoid
- check
- recommendation
- advice
- tip
- trick
- performance
---
On this page are presented recommendations and general guidelines for hardware usage with PostgreSQL

  1. Personal hardware
  2. Cloud
  3. Amazon Web Services (AWS)
  4. Things to avoid


### 1. Personal hardware

  * Get a lot of RAM, the more you do in cache, the better
  * CPU is usually not the bottleneck... so...
  * First step is hardware RAID, with:
   * RAID10 for the main database
   * RAID1 for the transaction logs
   * RAID1 for the boot disk

### 2. Cloud

Some guidelines to choose correct hardware for a PostgreSQL server for a cloud.

  * Get as much memory as you can
  * Get one CPU core per 2 active connections (usually, few connections are active...)
  * And hope that the I/O subsystem can keep up with your traffic

### 3. Amazon Web Services (AWS)

  * **Set up streaming replication**
  * Biggest instance you can afford
  * EBS for the data and transaction logs
  * Don’t use instance storage for any database data; OK for text logs
  * random\_page\_cost = 1.1

### 4. Things to avoid

A couple of things you should avoid:

  * Parity-disk RAID (RAID 5/6, Drobo, etc.)
  * iSCSI, especially for transaction logs
  * SANs, unless you can afford multichannel fibre
  * Long network hauls between the app server and database server
