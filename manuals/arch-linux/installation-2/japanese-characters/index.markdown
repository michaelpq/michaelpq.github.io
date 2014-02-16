---
author: Michael Paquier
date: 2012-04-20 04:38:34+00:00
layout: page
type: page
slug: japanese-characters
title: ArchLinux - Japanese
tags:
- archlinux
- dbus
- japanese
- input
- output
- utf8
- settings
- xinit
- initialization
- uim
- anthy
---

Everything necessary to set up an environment with Japanese character manipulation. Install uim and anthy, managing input of characters.

    pacman -S uim anthy

Add a Japanese font.

    pacman -S ttf-sazanami

Initialize UIM, for example in ~/.xinitrc.

    # Settings for Japanese input
    export GTK_IM_MODULE='uim'
    export QT_IM_MODULE='uim'
    uim-xim &
    export XMODIFIERS=@im='uim'

    #Toolbar for anthy
    uim-toolbar-gtk &

Then, in Settings->Input Methods (for XFCE), use those input methods (some are perhaps not really necessary):

    Anthy
    Anthy (UTF-8)
    Latin characters
    m17n-ja-anthy
    m17n-ja-tcode`

In order for the characters to be recognized, you might need to change /etc/locale.conf to set up the locale for the whole environment.

    LANG="ja_JP.UTF-8"
    LOCALE="en_US.UTF-8"

Then uncomment the following lines in /etc/locale.gen.

    en_US.UTF-8 UTF-8
    ja_JP.UTF-8 UTF-8

Finally generate the local parameters with locale-gen.

    $ locale-gen
    Generating locales...
      en_US.UTF-8... done
      ja_JP.UTF-8... done
    Generation complete.

You can display the locale settings with command locale.

    $ locale
    LANG=ja_JP.UTF-8
    LC_CTYPE="ja_JP.UTF-8"
    LC_NUMERIC="ja_JP.UTF-8"
    LC_TIME="ja_JP.UTF-8"
    LC_COLLATE="ja_JP.UTF-8"
    LC_MONETARY="ja_JP.UTF-8"
    LC_MESSAGES="ja_JP.UTF-8"
    LC_PAPER="ja_JP.UTF-8"
    LC_NAME="ja_JP.UTF-8"
    LC_ADDRESS="ja_JP.UTF-8"
    LC_TELEPHONE="ja_JP.UTF-8"
    LC_MEASUREMENT="ja_JP.UTF-8"
    LC_IDENTIFICATION="ja_JP.UTF-8"
    LC_ALL
