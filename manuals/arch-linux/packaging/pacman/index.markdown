---
author: Michael Paquier
date: 2012-04-18 07:36:30+00:00
layout: page
type: page
slug: pacman
title: 'ArchLinux - pacman'
tags:
- archlinux
- pacman
- package
- installation
- keyword
- specific
- dependency
- search
---
Here are a list of useful commands to be used with pacman. It may require
some specific settings if your environment is behind a proxy, so you
should have a look [here](/manuals/arch-linux/proxy-settings/).

Update and install the list of package.

    pacman -Suy

Perform a full upgrade, is necessary if some libraries are missing to
recompile system properly.

    pacman -Syyu

Install a new package.

    pacman -S $PACKAGE

Remove a package.

    pacman -R $PACKAGE

Remove a package and its dependent packages.

    pacman -Rs $PACKAGE

Look in package database for packages based on given keyword.

    pacman -Ss $KEYWORD

List of packages installed as dependencies but not used anymore.

    pacman -Qdt

List of packages explicitely installed, and not needed by other packages.

    pacman -Qet

List of packages with given keyword.

    pacman -Q | grep $KEYWORD

List of files installed with package.

    pacman -Ql $PACKAGE
