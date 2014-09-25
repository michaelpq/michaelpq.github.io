---
author: Michael Paquier
date: 2012-08-20 03:58:13+00:00
layout: page
type: page
slug: mount-drives
title: ArchLinux - Mount drives
tags:
- linux
- automate
- drive
- mount
- udiskie
- deployment
- laptop
- desktop
---
In order to automatically mount drives in ArchLinux, you can use udiskie
which is a wrapper of the natively available udev. You can install it
with the command below.

    pacman -S python2-udiskie

Once installed, you need to launch udiskie at session start-up. In order
to do that, add this line in .xinitrc before launching the window manager.

    udiskie &
