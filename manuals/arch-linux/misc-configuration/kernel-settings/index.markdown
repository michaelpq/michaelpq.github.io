---
author: Michael Paquier
date: 2012-11-13 06:40:21+00:00
layout: page
type: page
slug: kernel-settings
title: 'ArchLinux - Kernel settings'
tags:
- linux
- kernel
- settings
- archlinux
- arch
- dump
- file
- pattern
- memory
- shared
---

### Core file name

It is possible to personalize the core file name, for example:

    echo "core.%e.%p" > /proc/sys/kernel/core_pattern

In order to keep this setting at each boot, you need to set up /etc/sysctl.conf.

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

Increasing the shared memory that Linux kernel can use might be critical depending on the application used (especially Postgres version prior to 9.3). So add the following lines in /etc/sysctl.conf.

    (for 1GB)
    kernel.shmall = 262144
    kernel.shmmax = 1073741824
    (for 2GB)
    kernel.shmall = 524288
    kernel.shmmax = 2147483648
