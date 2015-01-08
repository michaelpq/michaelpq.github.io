---
author: Michael Paquier
lastmod: 2011-08-11
date: 2011-08-11 00:32:19+00:00
layout: post
type: post
slug: mount-physical-disks-in-linux
title: Mount physical disks in Linux
categories:
- Linux-2
tags:
- dev
- disk
- ext2
- ext3
- ext4
- fdisk
- linux
- mkfs
- mount
- ntfs
- physical
- tune2fs
---

Here is a little memo about mounting disks in Linux environment.
Let's imagine that you connected a new disk in your desktop with a SATA cable but then you don't know how to mount it. In this case this memo is made for you.

Be sure to have the root rights, and then identify the list of disk recognized by your computer with this command:

    fdisk -l

You will see a list of disk and their partitions. Each disk is identifiable with a name like /dev/sda, /dev/sdb. And each partition of the disk is identified by the name of the disk, and a partition number. For example for disk /dev/sda, it may have partitions called /dev/sda1, /dev/sda2.
By typing commands like:

    df -h

what you see is the physical status of each partition of a disk.

To mount a disk, you need first to write a partition table in it. Be sure of the name of the new disk connected. For this memo we take /dev/sdb, but it may be something else.

    fdisk /dev/sdb

After typing that, you can use "m" to display a help menu for the possible commands. Our goal here is creating a new partition table, so do:

  * n to create a new table	
  * p, and enter to create a new partition
  * 1, then enter if you want to number your partition as 1
  * w, then enter to save the new table and exit

By typing once again:

    fdisk -l

You will be able to see your disk completed with a new partition numbered /dev/sdb1.
Then you need to create a system file on it.
To create ext3 on it, type:

    mkfs.ext3 /dev/sdb1

You can create several types of system files like ext4, msdos, fat, ntfs (Windows), etc.
If you are a beginner, just choose the default options, it will be fine.

Then what I always do is:

    tune2fs -c 0 /dev/sdb1

To be sure that the disk is not checked whatever is the number of times it is mounted.

OK, now the disk is ready to be used. What you only need to do is to mount it to point to a folder.

    mkdir /mnt/newdisk
    mount /dev/sdb1 /mnt/newdisk

This disk can be unmounted with:

    umount /mnt/newdisk

You can also complete the file /etc/fstab. For that you need the UUID of the newly-added partition.

    ls /dev/disk/by-uuid/

You will see the list of disks listed by their IDs.
Finally edit /etc/fstab with a line like that to mount your new disk:

    UUID=$newdisk_uuid /mnt/newdisk    ext3    defaults 0 0

And be sure to replace $newdisk\_uuid by the ID of your new disk partition.

With /etc/fstab correctly completed, your new disk will be mounted automatically at each boot. If you don't want to reboot your machine, simply type:

    mount -a
