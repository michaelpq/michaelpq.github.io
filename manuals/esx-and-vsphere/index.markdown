---
author: Michael Paquier
date: 2013-03-02 12:11:45+00:00
layout: page
type: page
slug: esx-and-vsphere
title: 'ESX and vSphere'
tags:
- esx
- vsphere
- vmware
- development
- installation
- usb
- deployment
- fdisk
- manipulation
---

### Create bootable USB for install

Connect USB and create partition on it. Then use fdisk with that:

  1. n for new partition
  2. t for type at FAT32 (c)
  3. a to activate boot flag on partition 1
  4. p to check that partition is correct
  5. w to write partition and quit

The create file system on new partition (need package dosfstools on
Archlinux).

    mkfs.vfat -F 32 -n USB /dev/sdb1

Mount flash drive.

    mkdir /mnt/usb && mount /dev/sda1 /mnt/usb

Mount ESX installation ISO.

    mkdir /mnt/disk
    mount -o loop VMware-VMvisor-Installer-5.x.x-XXXXXX.x86_64.iso /mnt/disk

Copy content of disk on USB key.

    cp -r /usb/disk/* /mnt/usb

Rename config file for boot.

    mv /mnt/usb/isolinux.cfg /mnt/usb/syslinux.cfg

In the file /usbdisk/syslinux.cfg, change the line:

    APPEND -c boot.cfg

to:

    APPEND -c boot.cfg -p 1

Unmount stuff and you are done.

    umount /mnt/usb && umount /mnt/disk

Now the USB key can boot ESX installer.

### Intel NUC

ESXi 5.1 does not have network drivers for the model DYE of Intel NUC. So
installing it has needed to create a custom ISO with the network driver
included. The driver is called E1001E.tgz and program used to compile new
ISO was called ESXi-customizer. Look at that on the net if needed... At
least it worked correctly.

### ovftool

ovftool is a generic VMware command that can be used to save and deploy
VMs in ESX, vSphere, vCenter, Fusion, etc. Here is an example of how to
save an ova file (VM template with spec and disks compressed) from an
existing vmx file:

    ovftool $HOME/path/vm/machine.vmx $HOME/path/res/machine.ova
