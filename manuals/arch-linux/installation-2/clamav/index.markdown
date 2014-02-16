---
author: Michael Paquier
date: 2012-08-21 02:16:18+00:00
layout: page
type: page
slug: clamav
title: ArchLinux - Clamav
tags:
- archlinux
- clamav
- anti
- virus
- protection
- server
- install
- pacman
- settings
---
Clamav is an open-source anti-virus software. The name of its package is clamav.

    pacman -S clamav

Activate the daemon with systemctl.

    systemctl enable clamd.service

Here is a script to launch an script to scan all the folders of your system except /sys, /proc, /dev and the log files.

    #!/bin/bash
    # Daily scan for clamscan
    clamscan / \
      --infected \
      --recursive \
      --move=/var/log/clamav/virus \
      --log=/var/log/clamav/clamav_`date +%Y-%m-%d`.log \
      --exclude-dir=^/sys \
      --exclude-dir=^/proc \
      --exclude-dir=^/dev \
      --exclude-dir=^/var/log/clamav/virus
    # --infected put in log the list of infected files
    # --recursive recursive scan
    # --log log files
    # --move=DIR isolate infected files
    # --remove remove infected files
    # --exclude=FILE exclude some files
    # --exclude-dir=DIR exclude some directories

Here is a script to update the database automatically.

    #!/bin/sh
    # Update clamav virus database.
    LOG_FILE="/var/log/clamav/freshclam_`date +%Y-%m-%d`.log"
    /usr/bin/freshclam \
        --quiet \
        --log="$LOG_FILE"

You need to update the permission of those scripts to 755 and then place it to run them in cron like in /etc/cron.daily. You can also set up cron to launch then everyday at a certain time. Assuming both scripts are installed in /root/bin... First launch crontab.

    export EDITOR=vim && crontab -e

Then set up your scripts to be launched at 12PM everyday.

    00 12 * * * /root/bin/freshscan_daily
    00 12 * * * /root/bin/clamscan_daily`

You can check the contents of crontab with:

    crontab -l

Inside the configuration files /etc/clamav/clamd.conf and /etc/clamav/freshclam.conf, you need to uncomment the following lines.

    # Comment or remove the line below.
    # Example

You might need to setup some HTTP proxy for freshclam to work properly in /etc/clamav/freshclam.conf.

    # Proxy settings
    # Default: disabled
    #HTTPProxyServer proxy.example.com
    #HTTPProxyPort 8080
    #HTTPProxyUsername myusername
    #HTTPProxyPassword mypass
