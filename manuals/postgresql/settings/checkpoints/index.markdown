---
author: Michael Paquier
date: 2012-08-03 11:59:36+00:00
layout: page
type: page
slug: checkpoints
title: PostgreSQL - Checkpoints
tags:
- postgres
- postgresql
- settings
- tuning
- performance
- io
- disk
- flush
- memory
- checkpoint
- dirty
- buffer
- cache
- kernel
---

Here are some setting recommendations about checkpoints, some values
to set in postgresql.conf. A checkpoint consists of a complete flush
of dirty buffers to disk, so it potentially generates a lot of I/O. The
performance of your system will be impacted in those cases:

  * A particular number of WAL segments have been written
  * Timeout occurs

Here are some settings.

    wal_buffers = 16MB
    checkpoint_completion_target = 0.9
    checkpoint_timeout = 10m-30m # Depends on restart time
    checkpoint_segments = 32 # As a start value

Then, as a setting refinement, check if checkpoints happen more often
than checkpoint\_timeout, adjust checkpoint\_segments so that checkpoints
happen due to timeouts rather filling segments. Also, do not forget that
WAL can take up to 3 * 16MB * checkpoint\_segments on disk, and that
restarting PostgreSQL can take up to checkpoint\_timeout (but usually less).
