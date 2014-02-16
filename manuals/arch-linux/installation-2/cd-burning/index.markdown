---
author: Michael Paquier
date: 2012-08-20 04:19:34+00:00
layout: page
type: page
slug: cd-burning
title: Archlinux - CD burning
tags:
- cd
- burning
- utility
- archlinux
- xfburn
- data
- set
- install
---
A very useful solution for that introducing minimal dependencies is xfburn.

    pacman -S xfburn

With that you can burn, create iso images as well as burn a CD based on a set of data. Note: I personally tested brasero but fell on issues with blank CD detection. This looks to be related with dbus... However xfburn worked like a charm.
