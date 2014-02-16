---
author: Michael Paquier
date: 2012-04-18 08:07:27+00:00
layout: page
type: page
slug: proxy-settings
title: ArchLinux - Proxy
tags:
- archlinux
- proxy
- settings
- server
- ftp
- http
- bypass
- wget
---

Here is how to set a proxy on Arch if you use an XFCE environment.

### pacman settings

Uncomment the following line in /etc/pacman.conf.

    #XferCommand = /usr/bin/wget --passive-ftp -c -O %o %u

This allows pacman to use wget through a proxy.

In /etc/wgetrc, set up the proxy you need to go through by modifying http\_proxy.

    http_proxy = http://proxy.example.com:8080/

With those settings pacman should be able to get package data through a proxy.

### yaourt settings

It is not necessary to use root user for yaourt operations, package compilation and building is made on the user side. Only installation of package requires root rights. So, you need to set up proxy settings for your environment.

Here are the settings for HTTP/FTP/HTTPS proxy.

    export http_proxy=http://proxy.example.com:8080
    export HTTP_PROXY=http://proxy.example.com:8080
    export ftp_proxy=http://proxy.example.com:8080
    export FTP_PROXY=http://proxy.example.com:8080
    export all_proxy=http://proxy.example.com:8080
    export ALL_PROXY=http://proxy.example.com:8080
    export https_proxy=https://proxy.example.com:8080
    export HTTPS_PROXY=https://proxy.example.com:8080

Some applications use the upper case, other the lower case. So setting both is the safest. This permits to bypass proxy for certain IP requests.

    export no_proxy=localhost,.example.com,127.0.0.1
    export NO_PROXY=localhost,.example.com,127.0.0.1

### Browsers

I had a lot of problems to have Google Chrome work in XFCE behind a proxy because it was not possible to set up proxy settings as it fell back to the environment settings. Environment settings use variables like no\_proxy, http\_proxy but it happens that access to google services can be blocked by using no\_proxy. So I highly recommend to use Firefox, and everything went well!

