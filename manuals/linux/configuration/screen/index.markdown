---
author: Michael Paquier
date: 2013-01-03 12:08:04+00:00
layout: page
type: page
slug: Linux - screen
title: screen
tags:
- web
- server
- linux
- screen
- mirror
- dual
- hdmi
- output

---

Using xrandr is really straight-forward when trying to show a screen
externally as a mirror.

To show the list of outputs available just using this command is usually
enough. Here is an example of output with a Thinkpad connected:

    $ xrandr | grep connected
    eDP-1 connected 1920x1080+0+0 (normal left inverted right x axis y axis) 276mm x 155mm
    DP-1 disconnected (normal left inverted right x axis y axis)
    HDMI-1 disconnected (normal left inverted right x axis y axis)
    DP-2 disconnected (normal left inverted right x axis y axis)
    HDMI-2 connected 1920x1080+0+0 (normal left inverted right x axis y axis) 531mm x 298mm

An important thing is HDMI-2, that indicates the port connected to an
external source. Using a mirror screen can then be done like that:

    xrandr --output HDMI-2 --mode 1920x1080

Of course the output depends on the size of the monitor used.
