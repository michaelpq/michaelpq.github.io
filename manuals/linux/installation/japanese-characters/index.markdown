---
author: Michael Paquier
date: 2012-04-20 04:38:34+00:00
layout: page
type: page
slug: japanese-characters
title: Linux - Japanese
tags:
- linux
- dbus
- japanese
- input
- output
- utf8
- settings
- xinit
- initialization
- uim
- ibus
- anthy

---

Everything necessary to set up an environment with Japanese character
manipulation.  Install ibus and ibus-anthy, managing input of characters.

Add a Japanese font like ttf-sazanami

Initialize UIM, for example in ~/.xinitrc.

    # Settings for Japanese input
    export GTK_IM_MODULE='ibus'
    export QT_IM_MODULE='ibus'
    export XMODIFIERS=@im='ibus'

    #Toolbar for anthy
    ibus-daemon -drx

Then, launch ibus-setup (for i3), and add those input methods (some are
perhaps not really necessary) after looking for Japanese:

    Anthy
    Japanese

Using ibus-setup it is possible to make the current input method icon
to show up on the status bar. Be sure to set up that properly first.
Method switch is done with Super+space by default (super is likely the
Windows key).
