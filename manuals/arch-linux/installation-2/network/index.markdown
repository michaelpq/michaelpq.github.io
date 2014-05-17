---
author: Michael Paquier
date: 2012-11-04 05:01:04+00:00
layout: page
type: page
slug: network
title: Network
tags:
- archlinux
- network
- connection
- ip
- address
- static
- dhcp
- systemctl
---
There are multiple ways to install the network depending on what you are
looking for.

### Dynamic IP

In order to enable the dhcp, you need to use this command.

    systemctl enable dhcpcd@eth0.service

Or you can use netfg.

    pacman -S ifplugd
    cd /etc/network.d
    ln -s examples/ethernet-dhcp .
    systemctl enable net-auto-wired.service

### Static IP

Install ifplugd, which is required for net-auto-wired:

    pacman -S ifplugd

Copy a sample profile from /etc/network.d/examples to /etc/network.d:

    cd /etc/network.d
    cp examples/ethernet-static .

Edit the profile as needed:

    vi ethernet-static

Enable the net-auto-wired service:

    systemctl enable net-auto-wired.service

### Wireless

Install the following packages.

    pacman -S ifplugd wireless_tools wpa_supplicant wpa_actiond dialog

Archlinux uses now [netctl](https://wiki.archlinux.org/index.php/Netctl)
instead of netcfg.

If your wireless adapter requires a firmware (as described in the above
Establish an internet connection section and also here), install the
package containing your firmware. For example:

    pacman -S zd1211-firmware

For Intel n2200 series, install ipw2200-fw.

Then load the module for kernel.

    echo ipw2200-fw >> /etc/modules-load.d/wificard.conf

Connect to the network with wifi-menu (optionally checking the interface
name with ip link, but usually it's wlan0), which will generate a profile
file in /etc/network.d named after the SSID. There are also templates
available in /etc/network.d/examples/ for manual configuration. This will
also create a profile present in /etc/netctl.

    wifi-menu $INTERFACE

You might need to look at iwconfig or "id addr show" to find what is the
interface of the Wifi card. Enable the profile (with single profile).

    netctl enable $PROFILE

Check status of connection.

    systemctl status netctl@$INTERFACE.service`

### ifconfig

This command is in package net-tools.

    pacman -S net-tools
