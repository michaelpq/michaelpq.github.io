---
author: Michael Paquier
date: 2012-07-31 04:59:53+00:00
layout: page
type: page
slug: vbox
title: ArchLinux - VBox
tags:
- virtual
- box
- machine
- vm
- settings
- archlinux
- kvm
---
The installation of virtual box in ArchLinux can be done with the following
command.

    pacman -S virtualbox

Once installation has been done, it is necessary to load the kernel module
of virtual box driver. There are 2 ways to do that. Launch the module manually
at each reboot.

    modprobe vboxdrv

Or modify /etc/rc.conf by adding vboxdrv in the array MODULES for a result
like this:

    MODULES=(vboxdrv)
