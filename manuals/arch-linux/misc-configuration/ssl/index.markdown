---
author: Michael Paquier
date: 2013-01-11 14:21:54+00:00
layout: page
type: page
slug: ssl
title: ArchLinux - ssl
tags:
- archlinux
- security
- protocol
- protection
- ssl
- encrypted
- password
- granularity
- user
- group
- openssh
---

### Installation

    pacman -S openssh

### Activate ssh on server

    systemctl enable sshd.service

### Limit user access via ssh

Edit the file /etc/ssh/sshd\_config and add the following to limit access to a list of users.

    AllowUsers $USER1 $USER2

To limit the access to certain groups.

    AllowGroups group1 group2

To deny the access to some users.

    DenyUsers $USER1 $USER2

To deny the access to some groups.

    DenyGroups group1 group2
