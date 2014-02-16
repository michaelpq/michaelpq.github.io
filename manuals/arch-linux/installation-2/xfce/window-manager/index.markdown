---
author: Michael Paquier
date: 2012-04-24 00:05:52+00:00
layout: page
type: page
slug: window-manager
title: XFCE - Window manager
tags:
- archlinux
- xfce
- session
- desktop
- light
- slim
- window
- manager
- start
- reset
- update
---

In XFCE, it is possible that the window manager (XFWM) does not restart after an update. This will result in an XFCE session starting with all the windows stuck at the upper-left corner. This can be fixed by relaunching the XCFE window manager.

    xfwm4 --replace

To be sure that this is started correctly when session is launched, add that to $HOME/.xinitrc.

    exec sleep 5 && xfwm4 --replace
