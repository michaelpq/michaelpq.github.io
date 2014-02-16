---
author: Michael Paquier
date: 2013-06-03 06:47:38+00:00
layout: page
type: page
slug: rtorrent
title: ArchLinux - rtorrent
tags:
- torrent
- settings
- open source
- share
- server
- peer
- p2p
- pacman
- rtorrent
- protocol
- archlinux
---
Always useful to have when sharing open source things on the network.

    pacman -S rtorrent

#### Options

Here are some settings.

    min_peers = 40
    max_peers = 100
    max_uploads = 5
    directory = /home/[user]/doc/torrent
    session = /home/[user]/doc/torrent/session

    # Watch new torrent, and stop deleted ones
    schedule = watch_directory,5,5,load_start=/home/ioltas/doc/torrent/watch/*.torrent
    schedule = untied_directory,5,5,stop_untied=
    schedule = tied_directory,5,5,start_tied=

    # Close torrents when diskspace is low.
    schedule = low_diskspace,5,60,close_low_diskspace=100M

    # Port range should be more than 49152
    port_range = 49164-49164

    # Check for finished torrents
    check_hash = yes

    # encryption options
    encryption = allow_incoming,try_outgoing,enable_retry

    # DHT options
    dht = auto
    dht_port = 6881
    peer_exchange = yes

#### Key bindings

A couple of things to remember.

  * Ctl-d, stop an active download or remove a stopped download 
  * Ctl-s, start download. Runs hash first unless already done.
  * Ctl-q, quit application
  * Ctl-k, stop and close the files of an active download.
  * Ctl-r, initiate hash check for torrent
  * A|S|D and Z|X|C, change upload/download limit rates. 0 = unlimited
