---
author: Michael Paquier
date: 2013-01-03 11:56:27+00:00
layout: page
type: page
slug: raspberry-pi
title: Raspberry PI
tags:
- pocket
- pc
- computer
- specification
- small
- model
- A B
- raspberry PI
- micro SD
- install
- deployment
- michael
- paquier
- guide
- manual
---

Here is a small guide for the things that need to be done to set a Raspberry PI with Archlinux.

### OS setup

A Raspberry PI needs to be booted from the Micro SD slot.
First download the OS image directly from [this page](http://www.raspberrypi.org/downloads). Then insert your Micro SD in the appropriate slot and run the following command:

    dd bs=1M if=/path/to/archlinux-hf-YYYY-MM-DD.img of=/dev/sdX

YYYY-MM-DD is the date of the image downloaded (2012-09-18 when writing this page). Replace sdX by the number corresponding to the Micro SD you want to use.

Once the Micro SD is set up, insert it in the slot and plug in the adapter of the Raspberry PI. Then, you can run it correctly, the user name is root and password is root.

### Update packages

Update with those commands to have an up-to-date system.

    pacman -Sy pacman
    pacman-key --init
    pacman -S archlinux-keyring
    pacman-key --populate archlinux
    pacman -Syu --ignore filesystem
    pacman -S filesystem --force`

### Resize the Micro SD card

The image uploaded cannot use the full space of the SD card. First use fdisk and change the partition table of the SD card.

    fdisk /dev/mmcblk0

Then type 'p' to show the current partition.
            Device Boot      Start         End      Blocks   Id  System
    /dev/mmcblk0p1   *        2048      194559       96256    c  W95 FAT32 (LBA)
    /dev/mmcblk0p2          194560     3862527     1833984   83  Linux

You need to change the size of partition mmcblk0p2, so remove it with 'd', then type 2. Then recreate a new partition with 'n'. Create it as a primary with the first slot being the number shown previously with 'p' (here 194560) and the last slot being the default. Write new table with 'w' and quit fdisk with 'q'. Finally reboot.

Then run the following command:

    resize2fs /dev/mmcblk0p2

And you are done. Note: You might need to add the following line in /etc/fstab.

    /dev/mmcblk0p2 / ext4 defaults,noatime,nodiratime 0 0

### Swap file

You never know when you might need one, but here are a couple of commands to create it.

    fallocate -l 128M /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

Then add the following line to /etc/fstab.

    /swapfile none swap defaults 0 0
