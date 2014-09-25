---
author: Michael Paquier
date: 2013-03-09 14:07:09+00:00
layout: page
type: page
slug: intel-nuc
title: 'ArchLinux - Intel NUC'
tags:
- archlinux
- intel
- nuc
- sound
- aplay
- alsa
- install
---

Here are some settings specific for the Intel NUC.  

### Sound

The sound is propagrated through the HDMI. Install package alsa-utils.

Then set up the correct default card.

    $ aplay -l
    **** List of PLAYBACK Hardware Devices ****
    card 0: PCH [HDA Intel PCH], device 3: HDMI 0 [HDMI 0]
      Subdevices: 1/1
      Subdevice #0: subdevice #0
    card 0: PCH [HDA Intel PCH], device 7: HDMI 1 [HDMI 1]
      Subdevices: 1/1
      Subdevice #0: subdevice #0

Then you can set up ~/.asoundrc to load default card at user startup
or use /etc/asound.conf for system-wide settings.

    $ cat ~/.asoundrc 
    defaults.pcm.card 0
    defaults.pcm.device 7
    defaults.ctl.card 0

Card needs to be set at 0 for the Intel NUC, device at 3 or 7 depending
on the HDMI slot used. You can still find the speaker being used with
command speaker-test. Test it before setting it!

    speaker-test -D plughw:0,3 # for slot 1
    speaker-test -D plughw:0,7 # for slot 2
