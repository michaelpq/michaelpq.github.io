---
author: Michael Paquier
date: 2012-08-18 08:48:21+00:00
layout: page
type: page
slug: system-settings
title: Linux - System settings
tags:
- system
- settings
- linux
- central
- installation
- clock
- sync
- time
- internal
---

### hostname

Write your hostname to /etc/hostname.

### sync clock with network

Install the package ntp.

Then check the status of the software clock with this command, "NTP enabled"
should print "yes".

    # timedatectl status
          Local time: Wed 2013-07-10 15:39:56 JST
      Universal time: Wed 2013-07-10 06:39:56 UTC
            Timezone: Asia/Tokyo (JST, +0900)
         NTP enabled: yes
    NTP synchronized: yes
     RTC in local TZ: no
          DST active: n/a

Update the system clock if necessary after correct sync.

    hwclock --systohc

### timezone

Create a synbolic link from /etc/localtime to
/usr/share/zoneinfo/$ZONE/$SUBZONE. Replace $ZONE and $SUBZONE to your
time zone. For example:

    ln -s /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

### locale

Set locale preferences in /etc/locale.conf. Uncomment the selected
locale in /etc/locale.gen and generate it with:

    locale-gen

### Kernel settings

Set up /etc/mkinitcpio.conf to your liking and create an initial RAM disk.

    mkinitcpio -p linux

### Fonts

bitstream-vera is a nice font for programming, with package
ttf-bitstream-vera
