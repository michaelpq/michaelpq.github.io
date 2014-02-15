---
author: Michael Paquier
comments: true
date: 2012-01-10 02:31:34+00:00
layout: post
type: post
slug: control-dump-file-name-in-linux
title: Control dump file name in Linux
wordpress_id: 710
categories:
- Linux-2
tags:
- control
- core
- core_pattern
- development
- dump
- fedora
- kernel
- linux
- name
- ubuntu
---

Modifying the format name of dump file in a Linux system can be made with sysctl like this.

    sysctl -w kernel.core_pattern=core.%e.%p

However, making this modification command-based will not make it effective at next reboot.

In order to make the modification permanent, you need to edit the file /etc/sysctl.conf. Here the core file has the executable name %e and the process ID %p.

    kernel.core_pattern = core.%e.%p

Here is a list of the possible keywords usable:

  * %p, PID of dumped process
  * %u, (numeric) real UID of dumped process
  * %g, (numeric) real GID of dumped process
  * %s, number of signal causing dump
  * %t time of dump, expressed as seconds since the Epoch, 1970-01-01 00:00:00 +0000 (UTC)
  * %h, hostname (same as nodename returned by uname(2))
  * %e, executable filename (without path prefix)
  * %c, core file size soft resource limit of crashing process (since Linux 2.6.24)
