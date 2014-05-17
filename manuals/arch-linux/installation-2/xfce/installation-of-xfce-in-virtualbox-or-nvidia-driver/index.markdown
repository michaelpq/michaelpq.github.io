---
author: Michael Paquier
date: 2012-04-18 08:59:26+00:00
layout: page
type: page
slug: installation-of-xfce-in-virtualbox-or-nvidia-driver
title: XFCE - Basics
tags:
- xfce
- installation
- deployment
- pacman
- archlinux
- window
- desktop
- initialize
- slim
- graphic
---
Here are the details to install XFCE, a light-weight desktop system.
With the unusable Unity and Gnome switching to Gnome 3, more and more
people are moving to such light environments. This page supposes that
you already installed an ArchLinux environment (went to the end of the
ISO install). You might have installed this iso in a new machine or a
VirtualBox, this page covers both cases as desktop install is very
close for both environments.

When installing a system recommend the following packages:

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
  * 3. Install dbus
  * 4. Graphical drivers
  * 5. Install Desktop
  * 6. Desktop launcher

### 1. Setting up user

A user $USERNAME has to be added to some specific groups.

    useradd -m -g users -G audio,lp,optical,storage,video,wheel,games,power,scanner \
        -s /bin/bash $USERNAME

Then modify its password with this command.

    passwd $USERNAME

### 2. Install Xorg stuff

Install those packages.

    pacman -S xorg-server xorg-xinit

### 3. Install dbus

Install this package.

    pacman -S dbus

Start service.

    rc.d start dbus

Add dbus in the list of bootable daemons.

    systemctl enable dbus

### 4. Graphical drivers

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

### 5. Install desktop

Install those packages, first XFCE stuff.

    pacman -S xfce4

Then its goodies (highly recommended).

    pacman -S xfce4-goodies

Desktop is now basically installed, but you need a launcher.

### 6. Desktop launcher

There are several ways to do that, I prefer using slim which is light-weight
and fast, so... There are other options also.

    pacman -S slim

Then activate slim to become your active display manager.

    systemctl enable slim.service

This makes your session to balance to slim instead of moving to a terminal
at boot. Then the final part, you need to initialize your session to launch
XFCE at login. If this is not done correctly, you will finish with an error
at login screen "cannot execute login command". So create the file ~/.xinitrc.
You can also copy the content below:

    #!/bin/sh
    #
    # ~/.xinitrc
    #
    # Executed by startx (run your window manager from here)
    if [ -d /etc/X11/xinit/xinitrc.d ]; then
      for f in /etc/X11/xinit/xinitrc.d/*; do
        [ -x "$f" ] && . "$f"
      done
      unset f
    fi
    # exec gnome-session
    # exec startkde
    # exec startxfce4
    # ...or the Window Manager of your choice
    exec ck-launch-session startxfce4

Here the essential part is "exec ck-launch-session startxfce4" used to
launch your xfce session for chosen user.

### Specific drivers

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
