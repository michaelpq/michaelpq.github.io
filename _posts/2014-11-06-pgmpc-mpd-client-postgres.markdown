---
author: Michael Paquier
comments: true
lastmod: 2014-11-06
date: 2014-11-06 06:57:47+00:00
layout: post
type: post
slug: pgmpc-mpd-client-postgres
title: 'pgmpc: mpd client for Postgres'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- extension
- mpd
- music
- control
- playlist
- daemon
- player
- song

---

Have you ever heard about [mpd](http://www.musicpd.org/)? It is an open
source music player that works as a server-side application playing
music, as well as in charge of managing the database of songs, playlists.
It is as well able to do far more fancy stuff... Either way, mpd has a set
of client APIs making possible to control the operations on server called
libmpdclient, library being used in many client applications available
in the wild, able to interact with a remote mpd instance. The most used
being surely mpc, ncmpc and gmpc. There are as well more fancy client
interfaces like for example libmpdee.el, an elisp module for emacs.
Now, PostgreSQL has always lacked a dedicated client interface, that's
where [pgmpc]
(https://github.com/michaelpq/pg_plugins/tree/master/pgmpc) fills the
need (is there one btw?), by providing a set of SQL functions able to
interact with an mpd instance, so you can control your music player
directly with Postgres.

In order to compile it, be sure to have libmpdclient installed on your
system. Note as well that pgmpc is shaped as an [extension]
(http://www.postgresql.org/docs/devel/static/extend-extensions.html), so
once its source installed it needs to be enabled on a Postgres server
using [CREATE EXTENSION]
(http://www.postgresql.org/docs/devel/static/sql-createextension.html).

Once installed, this list of functions, whose names are inspired from
the existing interface of mpc, are available.

    =# \dx+ pgmpc
       Objects in extension "pgmpc"
            Object Description
    ----------------------------------
     function mpd_add(text)
     function mpd_clear()
     function mpd_consume()
     function mpd_load(text)
     function mpd_ls()
     function mpd_ls(text)
     function mpd_lsplaylists()
     function mpd_next()
     function mpd_pause()
     function mpd_play()
     function mpd_playlist()
     function mpd_playlist(text)
     function mpd_prev()
     function mpd_random()
     function mpd_repeat()
     function mpd_rm(text)
     function mpd_save(text)
     function mpd_set_volume(integer)
     function mpd_single()
     function mpd_status()
     function mpd_update()
     function mpd_update(text)
     (22 rows)

Currently, what can be done is to control the player, the playlists, and
to get back status of the player. So the interface is sufficient enough
for basic operations with mpd, enough to control mpd while being still
connected to your favorite database.

Also, the connection to the instance of mpd can be controlled with the
following GUC parameters that can be changed by the user within a single
session:

  * pgmpc.mpd_host, address to connect to mpd instance. Default is "localhost"
  This can be set as a local Unix socket as well.
  * pgmpc.mpd_port, port to connect to mpd instance. Default is 6600.
  * pgmpc.mpd_password, password to connect to mpd instance. That's optional
  and it is of course not recommended to write it blankly in postgresql.conf.
  * pgmpc.mpd_timeout, timeout switch for connection obtention. Default is
  10s.

In any case, the code of this module is available in [pg_plugins]
(https://github.com/michaelpq/pg_plugins) on github. So feel free to
send pull requests or comments about this module there. Patches to
complete the existing set of functions are as well welcome.
