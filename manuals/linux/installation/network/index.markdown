---
author: Michael Paquier
date: 2012-11-04 05:01:04+00:00
layout: page
type: page
slug: network
title: Network
tags:
- linux
- network
- connection
- ip
- address
- static
- dhcp
- systemctl

---

There are multiple ways to install the network depending on what you are
looking for.  Some exceptions are described here.

### Wireless

Install the following packages: ifplugd wireless\_tools
wpa\_supplicant wpa\_actiond dialog

Linux uses now [netctl](https://wiki.linux.org/index.php/Netctl)
instead of netcfg.

If your wireless adapter requires a firmware (as described in the above
Establish an internet connection section and also here), install the
package containing your firmware. For example zd1211-firmware.

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

This command is in package net-tools, but these days just rely on "ip"
and be a native person.

### rfkill

It may be possible that the wifi card is blocked by the kernel. To list
all the systems that may be impacted it is possible to list them with
this command:

    $ rfkill list all
    0: phy0: Wireless LAN
    Soft blocked: yes
    Hard blocked: no
    1: acer-wireless: Wireless LAN
    Soft blocked: yes
    Hard blocked: no

If the interface is soft blocked, it is possible to unblock it as follows

    rfkill unblock wifi
    rfkill unblock bluetooth

With Linux on a Thinkpad it could be possible that things are blocked,
causing for example the interface to load appropriately at boot phase and
making the network not to work from time to time.
