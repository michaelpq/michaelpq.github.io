---
author: Michael Paquier
date: 2012-10-17 01:56:58+00:00
layout: page
type: page
slug: i3
title: i3
tags:
- i3
- linux
- graphic

---
Here are the details to install the i3 window manager.

With the unusable Unity and Gnome switching to Gnome 3, more and more
people are moving to such light environments. This page supposes that
you already installed an Linux environment (went to the end of the
ISO install). You might have installed this iso in a new machine or a
VirtualBox, this page covers both cases as desktop install is very
close for both environments.

When installing a system the following packages are recommended:

  * mlocate, when installing from a core image,
  in this case the command updatedb can accelerate the process
  * readline, zlib and base-devel.
  * iptables, you need absolutely a firewall. But be sure to add
  iptables in daemons with "systemctl enable iptables"

A tip here, you can change virtual desktop with Alt+Fn, there are
6 virtual terminals available :). Don't forget to update your list of
packages first!

### Setting up user

A user $USERNAME has to be added to some specific groups, UID being important to
maintain compatibility for user-level permissions in the case where files are
transfered across machines.

    useradd -m -g users -G audio,lp,optical,storage,video,wheel,games,power,scanner \
        -u $UID -s /bin/bash $USERNAME

Add later on a user to a given group:

    gpasswd -a $USERNAME $GROUPNAME

Then modify its password with this command.

    passwd $USERNAME

### Install Xorg stuff

Install those packages: xorg-server xorg-xinit

Here is a package installing xsetroot, able to set a monocolor font
as desktop background: xorg-xsetroot

Adjust screen size with something like this command.

    xrandr --output Virtual1 --mode 1360x768

--output can be determined by looking at the output of xrandr and --mode
will be something listed there.

To make such settings persistent, it is necessary to create a configuration
file in /etc/X11/xorg.conf.d/, like 10-monitor.conf:

    Section "Screen"
      Identifier "Screen0"
      Monitor "Virtual1"
      SubSection "Display"
        Modes "1360x768"
      EndSubSection
    EndSection

This is suitable for a screen in a virtual machine (Identifier=Virtual1)
for a screen size of 1360x768.

#### NVIDIA drivers

Install the following packages: nvidia

Run this command to configure your card:

    nvidia-xconfig

#### Intel drivers

Install: xf86-video-intel libva-intel-driver

libva-intel-driver is useful for acceleration on newer GPU.

### Monitor

Xorg needs a monitor that will work as an extra layer with the window
manager. Slim is light, and may be a good choice (at least it has never
failed the other of this site).

This makes your session to balance to slim instead of moving to a terminal
at boot.

### Window manager

This heavily depends on the system you want.

After installation what is needed is ~/.xinitrc with something like that:

    exec i3

### Specific drivers

In a virtual environment, you might find the error:

    Fatal server error, no screens found

This error usually happens because xorg is not able to find the correct
video driver.

#### Virtual Box

Install xf86-video-vesa, then add vboxdrv in /etc/modules-load.d/ to
allow the drivers to be booted at startup.
