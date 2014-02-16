---
author: Michael Paquier
comments: true
lastmod: 2011-03-10
date: 2011-03-10 09:55:14+00:00
layout: post
type: post
slug: 7z-and-rar-compression-format-in-ubuntu-or-other-linux-distributions
title: 7z and rar compression format in Ubuntu or other Linux distributions
wordpress_id: 233
categories:
- Linux-2
tags:
- 7z
- apt
- archive
- compression
- debian
- distribution
- extract
- file
- linux
- p7zip
- package
- rar
- rpm
- ubuntu
- unrar-free
---

Sometimes you have to face some formats that are not installed by default in Ubuntu environments.
And it may be a problem if you cannot extract such archives.

Fortunately, there are some free applications provided with your distribution.
If you are not using Ubuntu, you can find debian or rpm packages easily.
In order to do that, there is this useful RPM package searcher
or this [Debian package searcher](http://www.debian.org/distrib/packages.en.html).

For Ubuntu, which is well... Debian based... (But it uses an APT system to manage its distribution packages)
Here is how to install those packages with commands (geek-mode).
To install rar format manager:

    sudo apt-get install unrar-free

To install 7z format manager:
    sudo apt-get install p7zip

Or for beginners you can find the packages in the software package center.
For that you have just to make a research with p7zip and unrar-free for each application in the Ubuntu Software Center in the Application tab of your menu bar.

To decompress a file with p7zip, you have to do the following command:

    7z x $FILE_NAME

$FILE_NAME being the name of your 7z file.

To decompress a file with unrar-free, you have to do the following command:

    unrar-free x $FILE_NAME

$FILE_NAME being the name of your rar file.
