---
author: Michael Paquier
date: 2017-01-11 12:19:37+00:00
layout: page
type: page
slug: debian
title: Debian
tags:
- debian
- linux
- distribution
- notes
- package
- thinkpad
- unstable
- i3
- mutt
- wifi

---

Here are some notes about installing Debian on a Thinkpad, when things
come to a fully-blown desktop environment with the following characteristics:

  * Unstable version of Debian is used (sid).
  * i3 is used as desktop, meaning that X is used as display manager.
  * a SIM card can be potentially used.
  * acpi is used to trigger keyboard events.
  * Firmware updates can be automatically managed without Windows.

## Installing Unstable (SID)

After downloading the net installer, install things with a minimal setting,
and do *not* install any desktop environments. Once the basic installation is
done, use the following lines in /etc/apt/sources.list:

    deb https://ftp.jp.debian.org/debian/ sid main contrib non-free
    deb-src https://ftp.jp.debian.org/debian/ sid main contrib non-free

The mention of "sid" ensures that unstable is used for the repository syncs.
"contrib" and "non-free" give access to more packages, including non-free
drivers usable for a Thinkpad.

Then run the following commands:

    apt-get update
    apt-get dist-upgrade

And the environment should be able to run on SID with all the packages wanted.

## Wifi and WWAN (SIM card)

By default Debian does not include the Wifi and WWAN drivers for the thinkpad,
however, those are available in the package *iwlwifi*. In order to be able to
install those, add "contrib" and "non-free" to /etc/apt/sources.list.
Note that depending on the evolution of Debian, these may not be supported,
requiring to look at git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git
with a combination of a copy of these binaries to /usr/lib/firmware/.

## USB mounting

For automatic USB mounting, *usbmount* is not supported anymore since Debian
Stretch, so an alternative is to use *udiskie*.

## Keyboard hotkeys with acpi

Gentoo provides a set of scripts that can be used for volume
[here](https://wiki.gentoo.org/wiki/Lenovo_ThinkPad_S440#ACPI_-_Sound_Management),
and for brightness [here](https://wiki.gentoo.org/wiki/ACPI/ThinkPad-special-buttons#Brightness_up).

And those really facilitate your life!

## Sound drivers

The sound drivers may not be available on the latest Debian, requiring
to look at https://github.com/thesofproject/sof-bin/ to install some
extra files not available yet (see its README.md). As a whole, dmesg
provides also a lot of debug output.

## i3 and desktop

### wifi connection tracking

Package *network-manager-gnome* comes with a nice binary called nm-applet
which can be used to have a small menu on the i3 status bar, including
tracking for SIM card connection! Just add that to .i3config and you
are good to go:

    exec --no-startup-id nm-applet --sm-disable

### Login screen

Install a display manager like *lightdm*. Note that lightdm does not load
directly .xinitrc contrary to slim, but you can override that by using
.xsession in the following way for example:

    # Tweak to enforce settings to be loaded when logging in.
    /bin/bash --login -i ~/.xinitrc

### X server

Here are some useful packages as well:

  * x11-xserver-utils for xrdb

### Autolock and screensaver

*xautolock* can be used for this purpose.

### Font

*ttf-bitstream-vera* is a nice font package that can be used.

## Power control

Debian does not create a "wheel" group or "power" group, but those
can be controlled using systemctl;

    systemctl poweroff
    systemctl reboot

## Manual RPM installation

If Debian SID gets broken because of a package dependency not correctly
handled in the central repositories, it is always possible to enforce
the installation of packages manually.  First download the .deb file
to install, this can be done using apt like that:

    apt download $PACKAGE

If this cannot be found, it is also possible to download it from Debian's
FTP servers, by first going into one of the
[mirrors](https://www.debian.org/mirror/list), like
[this one](ftp.jp.debian.org/debian/), then navigate to
pool/main/$FIRST\_LETTER\_PACKAGE/$PACKAGE ("main" may change depending
on the package category).  For example for perl the URL would be
pool/main/p/perl.  Then finally install the package manually:

    dpkg -i $PACKAGE.deb

Depending on the different dependencies, it may be necessary to repeat
those steps multiple times for multiple packages.

## Firmware updates

Things go through [fwupd](https://github.com/fwupd/fwupd), flawlessly
and automatically.  A package of the same name should be installed to
make this utility available.  Some useful commands.

Get the list of devices set on the device:

    fwupdmgr get-devices

Refresh the latest firmware metadata:

    fwupdmgr refresh

If updates are available, display them:

    fwupdmgr get-updates

Perform a set of firware updates:

    fwupdmgr update
