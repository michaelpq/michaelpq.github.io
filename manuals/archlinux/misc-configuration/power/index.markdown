---
author: Michael Paquier
date: 2016-11-01 01:51:47+00:00
layout: page
type: page
slug: power
title: 'ArchLinux - Power'
tags:
- archlinux
- linux
- settings
- optional
- optimize
- power
- consumption

---

Here are some tricks to optimize power consumption on a laptop.

### Powertop

First install it:

    pacman -S powertop

Then create /etc/systemd/system/powertop.service to enable it as a service.

    [Unit]
    Description=Powertop tunings

    [Service]
    Type=oneshot
    ExecStart=/usr/bin/powertop --auto-tune

    [Install]
    WantedBy=multi-user.target

Then enable it as a service.

    systemctl enable powertop

