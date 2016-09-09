---
author: Michael Paquier
date: 2012-08-18 08:48:21+00:00
layout: page
type: page
slug: system-settings
title: ArchLinux - System settings
tags:
- system
- settings
- archlinux
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

    pacman -S ntp

Then register it as a daemon.

    systemctl enable ntpd

Or with that:

    timedatectl set-ntp 1

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

Finally start the daemon if you do not want to reboot the server.

    systemctl start ntpd

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

bitstream-vera is a nice font for programming.

    pacman -S ttf-bitstream-vera

### Synchronize clock with guest in VMware VM

Install and enable those modules.

    pacman -S open-vm-tools open-vm-tools-modules
    systemctl enable vmtoolsd
    cat /proc/version > /etc/arch-release

Then set host machine as time source.

    ware-toolbox-cmd timesync enable

Then synchronize clock for a sleep.

    sudo hwclock --hctosys --localtime
