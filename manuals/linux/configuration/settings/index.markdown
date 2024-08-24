---
author: Michael Paquier
date: 2012-11-13 06:40:21+00:00
layout: page
type: page
slug: kernel
title: 'Linux - Settings'
tags:
- manual
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
