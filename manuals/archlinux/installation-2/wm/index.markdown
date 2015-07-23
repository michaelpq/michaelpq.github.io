---
author: Michael Paquier
date: 2012-10-17 01:56:58+00:00
layout: page
type: page
slug: xfce
title: XFCE
tags:
- xfce
- install
- archlinux
- graphic
- card
- slim
- installation
- linux
- xfce
- i3
- awesome

---
Here are the details to install a window manager. There are many
choices available under-the-hood, among them:

  * XFCE, a light-weight desktop system.
  * i3, a light-weight window tiling manager
  * awesome, other light-weight window tiling manager, using lua for
  configuration

With the unusable Unity and Gnome switching to Gnome 3, more and more
people are moving to such light environments. This page supposes that
you already installed an ArchLinux environment (went to the end of the
ISO install). You might have installed this iso in a new machine or a
VirtualBox, this page covers both cases as desktop install is very
close for both environments.

When installing a system the following packages are recommended:

  * mlocate, when installing from a core image, you may find some
  corrupted package keys, and may be forced to use pacman-key --init,
  in this case the command updatedb can accelerate the process
  * readline, zlib and base-devel. Useful for an environment for
  PostgreSQL
  * iptables, you need absolutely a firewall. But be sure to add
  iptables in daemons with "systemctl enable iptables"

A tip here, you can change virtual desktop with Alt+Fn, there are
6 virtual terminals available :). Don't forget to update your list of
packages first!

    pacman -Suy

This guide is divided into several parts.

  * 1. Setting up user
  * 2. Xorg stuff
  * 3. Graphical drivers
  * 4. Monitor
  * 5. Window manager
  * 6. Specific drivers

### 1. Setting up user

A user $USERNAME has to be added to some specific groups.

    useradd -m -g users -G audio,lp,optical,storage,video,wheel,games,power,scanner \
        -s /bin/bash $USERNAME

Add later on a user to a given group:

    gpasswd -a $USERNAME $GROUPNAME

Then modify its password with this command.

    passwd $USERNAME

### 2. Install Xorg stuff

Install those packages.

    pacman -S xorg-server xorg-xinit

Here is a package installing xsetroot, able to set a monocolor font
as desktop background.

    pacman -S xorg-xsetroot

### 3. Graphical drivers

This part differs if you use a VirtualBox or an environment with nvidia
drivers.

#### NVIDIA drivers

Install the following packages.

    pacman -S nvidia

Run this command to configure your card.

    nvidia-xconfig

#### Intel drivers

Install that:

    pacman -S xf86-video-intel libva-intel-driver

libva-intel-driver is useful for acceleration on newer GPU.

#### VirtualBox

Install the following packages.

    pacman -S virtualbox-guest-modules virtualbox-guest-utils \
            kernel26-headers

You also need to set the kernel so as the vbox modules are launched
automatically at each boot. It is necessary to create a configuration
file /etc/modules-load.d/vbox.conf.

    vboxguest
    vboxsf
    vboxvideo

You can however launch them like this, but this has to be done at each
boot.

    modprobe -a vboxguest vboxsf vboxvideo

### 4. Monitor

Xorg needs a monitor that will work as an extra layer with the window
manager. Slim is light, and may be a good choice (at least it has never
failed the other of this site).

    pacman -S slim

Then activate slim to become your active display manager.

    systemctl enable slim.service

This makes your session to balance to slim instead of moving to a terminal
at boot.

### 5. Window manager

This heavily depends on the system you want, here are some examples. For
XFCE4, here are the packages.

    pacman -S [ xfce4 xfce4-goodies | i3 | awesome ]

Packages for i3, or even awesome are available. After installation what
is needed is ~/.xinitrc with something like that (depends on the window
manager installed though).

    exec ck-launch-session startxfce4
    exec i3
    exec awesome

### 6. Specific drivers

In a virtual environment, you might find the error:

    Fatal server error, no screens found

This error usually happens because xorg is not able to find the correct
video driver.

#### Virtual Box

Launch this command.

    pacman -S xf86-video-vesa

Then add vboxdrv in /etc/modules-load.d/ to allow the drivers to be
booted at startup.

#### VMWare fusion

Install that:

    pacman -S xf86-input-vmmouse xf86-video-vmware svga-dri

Then add vmwgfx in /etc/modules-load.d/ to allow the drivers to be booted
at startup. And you are done!
