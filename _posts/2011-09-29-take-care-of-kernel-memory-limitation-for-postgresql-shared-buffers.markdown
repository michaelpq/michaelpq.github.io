---
author: Michael Paquier
comments: true
date: 2011-09-29 01:39:10+00:00
layout: post
slug: take-care-of-kernel-memory-limitation-for-postgresql-shared-buffers
title: Take care of kernel memory limitation for postgresql shared buffers
wordpress_id: 526
categories:
- PostgreSQL-2
tags:
- '9.0'
- '9.1'
- '9.2'
- customize
- database
- kernel
- postgres
- postgresql
- server
- setting
- shared_buffers
- shmall
- shmmax
- tuning
- ubuntu
---

When tuning a PostgreSQL server, one the major setting parameters is the one controlling the amount of shared memory allowed with shared_buffers.
PostgreSQL has a default shared_buffers value at 32MB, what is enough for small configurations but it is said that this parameter should be set at 25% of the system's RAM. This allows your system to keep a good performance in parallel with the database server.
So in the case of a machine with 4GB of RAM, you should set shared_buffers at 1GB.

In the case of ubuntu servers, you may find the following error when starting a PostgreSQL instance.

    FATAL:  could not create shared memory segment:
    DETAIL:  Failed system call was shmget(key=5432001, size=1122263040, 03600).
    HINT:  This error usually means that PostgreSQL's request for a shared memory segment exceeded your kernel's SHMMAX parameter.  You can either reduce the request size or reconfigure the kernel with larger SHMMAX.  To reduce the request size (currently 1122263040 bytes), reduce PostgreSQL's shared memory usage, perhaps by reducing shared_buffers or max_connections.
    If the request size is already small, it's possible that it is less than your kernel's SHMMIN parameter, in which case raising the request size or reconfiguring SHMMIN is called for.
    The PostgreSQL documentation contains more information about shared memory configuration.`

This means that Linux kernel cannot allow more shared memory than the kernel can.
In order to prevent that, customize the memory parameters of your machine kernel.

    (for 1GB)
    sysctl -w kernel.shmmax=1073741824
    sysctl -w kernel.shmall=262144
    (for 2GB)
    sysctl -w kernel.shmmax=2147483648
    sysctl -w kernel.shmall=524288`
    You need root rights to modify those parameters.

Using sysctl will not reinitialize those parameters at reboot. For a more permanent solution, add the following lines to /etc/sysctl.conf.

    (for 1GB)
    kernel.shmall = 262144
    kernel.shmmax = 1073741824
    (for 2GB)
    kernel.shmall = 524288
    kernel.shmmax = 2147483648
