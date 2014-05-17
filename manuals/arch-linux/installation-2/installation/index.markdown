---
author: Michael Paquier
date: 2012-08-16 04:10:49+00:00
layout: page
type: page
slug: installation
title: ArchLinux - Basics from ISO
tags:
- archlinux
- linux
- installation
- iso
- scratch
- fdisk
- create
- keyboard
- done
- connect
---
Since build of August 2012, ArchLinux has removed the setup menu. Now
when launching an iso image for a new installation, it is necessary to
set up all the disk partitions from scratch, then create a file system
on them, and finally install the system by yourself. This is already
nicely defined in [ArchLinux Wiki]
(https://wiki.archlinux.org/index.php/Beginners%27_Guide), but this
beginner's guide is far too long and does not focus on the main points
of the installation. So here is in successive steps how to install
ArchLinux on a system easily, until the point where you are able to boot
your system. More detailed settings can come later.

### Keyboard layer

You can change the layer of your keyboard with this command.

    loadkeys layout

All the available layers are located in /usr/share/kbd/keymaps/. For
example in my case, the Japanese keyboard is jp106.

### Check network connection

Use this command or similar.

    ping -c 3 www.google.com

If you are unable to reach the network, you might need to setup your
network properly. You can refer to the [ArchLinux Wiki]
(https://wiki.archlinux.org/index.php/Beginners%27_Guide#Setup_network_in_the_live_installation_environment)
to perform that.

### Create the disk partitions

You need to create all your partitions from scratch. This can be done
nativaly with fdisk. The following architecture is recommended.

  * sda1, /, 20G. Used for root. This is the root of all the folders for
your system. All packages are installed here	
  * sda2, swap. Used for the system swap. Need a special partition type
82 (option 't' in fdisk)
  * sda3, home. Used for the home data. Normal user data. So you need
space here.

When using fdisk for the setup, you will need to use the following
commands.

  * w to write a partition and exit	
  * n to create a new partition
  * t to define the type of a partition
  * a to set up a boot flag on a partition

When using 't', you will need to use the partition number. To define a
swap, you need to use 82 as type. For a Windows NTFS, use 7. You can see
the list of available types with 'L'.
Create all the partitions successively, in the order written above. You
will need to precise the size of each partition, you should use the
default for start point and then a grammar like '+100M' or '+15GB' to add
a given size. The last partition sda4 cannot be set as Extended or it will
not be able to use a system file. Be sure to set it as Linux (type 83).
Do not forget to check the partition table with 'p'! Then exit with 'w'.

### Create file systems

So for the partitions root, boot and home.

    mkfs.ext4 /dev/sda1 #root
    mkfs.ext4 /dev/sda3 #home

Then for the swap partition.

    mkswap /dev/sda2 && swapon /dev/sda2

### Mount the partitions

You need to mount the partitions to allow installation of the packages on
disk.

    mount /dev/sda1 /mnt
    mkdir /mnt/home && mount /dev/sda3 /mnt/home

### Install the packages

Package installation can be done with this command once partitions are
mounted.

    pacstrap /mnt base base-devel

If you need to go through a proxy, you need special settings for pacman
[here](http://michael.otacoo.com/manuals/arch-linux/proxy-settings/).

### Generate fstab

This allows to mount automatically all the partitions defined.

    genfstab -p /mnt >> /mnt/etc/fstab

### chroot the system

Then say that the newly-installed system is.

    arch-chroot /mnt

### initial ramdisk environment

This is used to allow loading kernel modules.

    mkinitcpio -p linux

### Install bootloader

The bootloader that is going to be used is syslinux. grub2 has too many
configuration files and your host prefers simplicity.

    pacman -S syslinux

Then you need to edit the file /boot/syslinux/syslinux.cfg.

    ...
    LABEL arch
            ...
            APPEND root=/dev/sda3 ro
            ...

Change /dev/sda3 to indicate your root partition, here /dev/sda1. If you
do not do that correctly, ArchLinux will not boot. Then, do the same for
the section LABEL archfallback.

Finally you just need to install files (-i), to set up the boot flag (-a)
and to install MBR boot code (-m).

    syslinux-install_update -iam

Note that in the case of a proxy environment, wget might be necessary to
fetch the packages you need. You need to launch that before entering in
arch-chroot mode.

    pacstrap /mnt wget

### Root password

Setup a root password with:

    passwd

### Last moments before reboot

Leave chroot environment.

    exit

Unmount all the partitions.

    umount /mnt/home
    umount /mnt

And reboot. Remove the disk media. And then you should be able to run
ArchLinux.

    reboot
