---
author: Michael Paquier
date: 2015-02-28 14:07:09+00:00
layout: page
type: page
slug: raspberry-pi
title: 'ArchLinux - Raspberry PI'
tags:
- archlinux
- arm
- pi
- raspberry
- sound
- aplay
- alsa
- install

---

Here are some settings specific for the Raspberry PI.

### Sound

The sound is propagrated through the HDMI. Install the following packages:

    pacman -S # pacman -S alsa-utils alsa-firmware alsa-lib alsa-plugins

To enforce an output source, use the following command:

    amixer cset numid=3 $NUM

Where NUM can be of the following values:

  * 0 for Auto
  * 1 for Analog out
  * 3 for HDMI
