---
author: Michael Paquier
date: 2014-04-03 14:14:18+00:00
layout: page
type: page
slug: perf
title: PostgreSQL - Profiling with perf
tags:
- postgres
- postgresql
- performance
- cpu
- calls
- perf
- linux
- kernel
- production
- analysis
- server

---

The Linux kernel comes with a performance analysis tool called perf
that can even be used on production servers to analyze the call stack
of a server, or a process. This is useful to find the bottlenecks of
a query processing or simply of a server running and improve those.

It is usually found in the package "perf", at least it is the case
of RHEL, CentOS and ArchLinux.

/proc/sys/kernel/perf\_event\_paranoid can be used to restrict access
to the performance counters.

  * 2, allow only user-space measurements
  * 1, allow both kernel and user measurements (default)
  * 0, allow access to CPU-specific data
  * -1, no paranoid at all

### Record information

Profile system as long as needed, can be cancelled with Ctl-C:

    perf record -a -g

Profile system for a given period of time:

    perf record -a -g -s sleep $TIME_IN_SECONDS

For the duration of a command:

    perf record -a -g -s -- $COMMAND

Different things can be recorded:

   * -a to profile the whole system
   * -p $PID to profile only the given PID
   * -u $USER to profile only the given user

Reports are saved by default in $HOME/perf.data. Old reports are renamed
as $HOME/perf.data.old.

### Real-time measurement

This is done by perf top, like system-wide profiling:

    perf top

Profiling without accumulating stats:

    perf top -z

### View records

View profile recorded:

    perf report -n

With a graph:

    perf report -g
