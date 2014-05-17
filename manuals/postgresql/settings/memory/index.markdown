---
author: Michael Paquier
date: 2012-08-03 11:53:14+00:00
layout: page
type: page
slug: memory
title: PostgreSQL - Memory
tags:
- postgres
- postgresql
- open source
- database
- memory
- performance
- settings
- shared
- buffers
- work_mem
- cache
- maintenance
---
Here is a list of recommended parameters for memory management in PostgreSQL.
You should take into account mainly the following parameters.

    shared_buffers
    work_mem
    maintenance_work_mem
    effective_cache_size

About **shared\_buffers**:

  * Below 2GB, set to 20% of total system memory.
  * Below 32GB, set to 25% of total system memory.
  * Above 32GB, set to 8GB

About **work\_mem**, this parameter can cause a huge speed-up if set properly,
however it can use that amount of memory per planning node. Here are some
recommendations to set it up.

  * Start low: 32-64MB
  * Look for ‘temporary file’ lines in logs
  * Set to 2-3x the largest temp file

About **maintenance\_work\_mem**, here are some recommandations:

  * 10% of system memory, up to1GB
  * Maybe even higher if you are having VACUUM problems

About **effective\_cache\_size**, here are some guidelines.

  * Set to the amount of file system cache available
  * If you don’t know, set it to 50% of total system memory
