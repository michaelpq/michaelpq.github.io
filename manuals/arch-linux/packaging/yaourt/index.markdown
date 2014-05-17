---
author: Michael Paquier
date: 2012-04-18 07:49:31+00:00
layout: page
type: page
slug: yaourt
title: ArchLinux - yaourt
tags:
- archlinux
- yaourt
- pacman
- aur
- distribution
- custom
- build
- purpose
---
yaourt is a package manager in ArchLinux complementary to pacman. It is
useful to get packages that cannot be found through pacman. yaourt may
require some specific settings if your environment is behind a proxy,
so you should have a look [here](/manuals/arch-linux/proxy-settings/).  

### Installation

Installing yaourt is tricky. You need first to install package-query
which is a dependency. So to install package-query first be sure to
download PKGBUILD and tarball from [here]
(https://aur.archlinux.org/packages/package-query/).

    tar zxvf package-query.tar.gz
    cd package-query
    makepkg -si

You will find a pkg file, you can install it directly with pacman as
root.

    pacman -U package-query.pkg.XXX.tar.gz

Then you can install yaourt by downloading first PKGBUILD and tarball
[here](https://aur.archlinux.org/packages/yaourt/).

    tar zxvf yaourt.tar.gz
    cd yaourt
    makepkg

You will find once again a pkg file, install it with pacman as root.

    pacman -U yaourt.pkg.XXX.tar.gz

And you are done.  

### Commands

yaourt is honestly great, it will soon become your best friend on Arch.
It automatizes a lot the installation process of a bunch of packages
and functionnalities by fetching packages with curl from remotes,
compiling everything, making pkg files and install everything with
pacman. Here are some commands to use it. Search a list of packages
with a keyword.

    yaourt -S $KEYWORD

Once this is used, you will have to choose among a list of packages
what you want. Update system using AUR packages.

    yaourt -Syua
