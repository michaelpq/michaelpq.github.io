---
author: Michael Paquier
comments: true
lastmod: 2012-08-14
date: 2012-08-14 03:06:36+00:00
layout: post
type: post
slug: clean-install-of-macos-lion-and-mountain-lion
title: Clean install of MacOS Lion and Mountain Lion
wordpress_id: 1151
categories:
- MacOS
tags:
- '10.7'
- '10.8'
- clean
- install
- lion
- Lion DiskMaker2
- macos
- mountain
- operating system
- os
---

Each time a new OS is out, there are always cool new features you want to try and so you need absolutely to change the OS of your machine.
There are 2 ways to change the OS:
	
  * Upgrade the OS	
  * Perform a clean install

Upgrading the OS is approximately OK for MacOS as each new release maintains a certain consistency in the system. But you have to keep in mind that each upgrade might let old pieces of files on your system and those rests might interact with the new features you got in.

Personally, I am more a fan of the solution consisting of making a new system entirely from scratch instead of upgrading as such rests from past OS versions can really become annoying in long term.
There are several ways to perform a clean install of MacOS, but one caught my attention by its facility (aimed for lazy guys, like the author of this article).

There is a small utility called [Lion DiskMaker2](http://blog.gete.net/ldm/Lion_DiskMaker2.0.1.zip), whose final version 2.0 is out since the beginning of August 2012, allowing you to create a bootable USB key or a disk that can be used to install a MacOS at machine start-up. This is honestly useful, as you can set up everything in a couple of clicks.

So, here are the main steps to perform the clean install based on this utility.
	
  1. Download MacOS Mountain Lion 10.8.x or Lion 10.7 from the Apple Store.
  2. Download and launch Lion DiskMaker2 to create a bootable drive.
  3. DiskMaker2 will automatically detect the systems that can be installed on your drive. Then follow the instructions.
  4. In case you wish to use a USB drive, use at least something with 8GB of space
  5. Once the bootable drive is made, shutdown your machine.
  6. While maintaining pushed the Option key on Keyboard, start your machine. You are redirected to the MacOS backup screen.
  7. There are several disks listed like RecoveryHD, select the bootable drive you just built (its name has been defined when creating it with DiskMaker2)
  8. Enter the disk utility and then delete completely the original disk of your machine
  9. Install the OS of your USB key and follow the steps to finish this clean install

This description might lack of precisions, but installing a new MacOS version is really intuitive. Be only sure to press the Option key when restarting your machine!
