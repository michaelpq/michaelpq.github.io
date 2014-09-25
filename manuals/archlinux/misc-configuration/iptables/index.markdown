---
author: Michael Paquier
date: 2012-04-20 04:32:25+00:00
layout: page
type: page
slug: iptables
title: ArchLinux - iptables
tags:
- archlinux
- iptables
- protection
- firewall
- block
- ssl
- connection
- service
- stop
- start
- flush
- create
- rules
- protection
---
Set up a basic firewall in Arch with iptables. Install package iptables.

    pacman -S iptables

Then you need to add iptables in DAEMONS of /etc/rc.conf.

Look at the current status of firewall.

    iptables -L

Delete/flush all the rules of table.

    iptables -F

Save rules to file.

    iptables-save > /etc/iptables/iptables.rules

Restore rules from file.

    iptables-restore < /etc/iptables/iptables.rules

Start/Stop/Restart iptables service.

    systemctl enable/disable iptables.service

Example of iptables files.

    *filter
    :INPUT ACCEPT [368:102354]
    :FORWARD ACCEPT [0:0]
    :OUTPUT ACCEPT [92952:20764374]
    -A INPUT -i lo -j ACCEPT
    -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    -A INPUT -i eth0 -p tcp -m tcp --dport 22 -j ACCEPT
    -A INPUT -i eth0 -p tcp -m tcp --dport 80 -j ACCEPT
    -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7
    -A INPUT -j DROP
    COMMIT

Accept all the http and ssh connection. Drop if nothing suits. And log
if it arrives at this level. Accept all the local connections done with
loopback.

This example includes some restrictions on ssh to limit the number of
connections per IP in a given interval of time.

    *filter
    :INPUT ACCEPT [0:0]
    :FORWARD ACCEPT [0:0]
    :OUTPUT ACCEPT [52:6560]
    -A INPUT -i eth0 -p tcp -m tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name DEFAULT --mask 255.255.255.255 --rsource -j DROP
    -A INPUT -i eth0 -p tcp -m tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name DEFAULT --mask 255.255.255.255 --rsource
    -A INPUT -i lo -j ACCEPT
    -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    -A INPUT -i eth0 -p tcp -m tcp --dport 22 -j ACCEPT
    -A INPUT -i eth0 -p tcp -m tcp --dport 80 -j ACCEPT
    -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7
    -A INPUT -j DROP
    COMMIT

This can also be enabled with the following commands.

    iptables -I INPUT -p tcp --dport 22 -i eth0 -m state --state NEW -m recent --set
    iptables -I INPUT -p tcp --dport 22 -i eth0 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP`

Default rule file for iptables is defined in /etc/rc.d/iptables with
the environment variable IPTABLES\_CONF=/etc/iptables/iptables.rules.
Be sure to save your rules in this file or change IPTABLES\_CONF in
consequence.
