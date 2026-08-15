---
author: Michael Paquier
date: 2012-11-13 06:40:21+00:00
layout: page
type: page
slug: kernel
title: 'Linux - Kernel settings'
tags:
- linux
- kernel
- settings

---

### Core file name

It is possible to personalize the core file name, for example:

    echo "core.%e.%p" > /proc/sys/kernel/core_pattern

In order to keep this setting at each boot, you need to set up
/etc/sysctl.conf.

    kernel.core_pattern = core.%e.%p

The following flags can also be used.

    %p:       pid
    %:   '%' is dropped
    %%:       output one '%'
    %u:       uid
    %g:       gid
    %s:       signal number
    %t:       UNIX time of dump
    %h:       hostname
    %e:       executable filename

### Max shared memory and pages

Increasing the shared memory that Linux kernel can use might be critical
depending on the application used (especially Postgres version prior to
9.3). So add the following lines in /etc/sysctl.conf.

    (for 1GB)
    kernel.shmall = 262144
    kernel.shmmax = 1073741824
    (for 2GB)
    kernel.shmall = 524288
    kernel.shmmax = 2147483648

### Swapping

Only swap +50% of memory that can be handled by applications. Useful
to not freeze a laptop when debugging memory allocation problems on
an application.

    $ cat oom.conf
    vm.overcommit_memory = 2
    vm.overcommit_ratio = 50

### perf

Allow all perf events to be taken.

    $ cat perf_settings.conf
    kernel.perf_event_paranoid = -1

### I/O scheduler

The Linux kernel comes up with a set of scheduler that can be used to
alleviate the I/O behavior on disks and partitions.

  * noop, fine with SSDs, but can kill local disks on no-reordering
of writes. Has more effects for sequential I/O writes like WAL flush
by having pg\_xlog on a different partition for example.
  * deadline, great for Postgres but interactive workloads are impacted
by it.
  * cfq, a good balance for everything, and it is the default on Linux.

It is usually better to stick with the default scheduler except when
trying to solve a specific issue, also everything else than cfq would
perform badly on non-enterprise class storages (SAN).

### Write-heavy workloads

On systems facing heavy write load, tuning /etc/sysctl.conf like that
is worth doing:

    vm.dirty_background_ratio = 0
    vm.dirty_ratio = 0

In concurrent heavy-read loads, this setting can be useful for 3.13
kernels.

    kernel.sched_autogroup_enabled

Turning off swap entirely may also be worth considering.
