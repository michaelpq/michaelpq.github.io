---
author: Michael Paquier
date: 2013-03-26 01:44:17+00:00
layout: page
type: page
slug: irssi
title: ArchLinux - irssi
tags:
- irssi
- channel
- talk
- tip
- irc
- programming
- server
- freenode
- archlinux
- configuration
- install

---

irssi is a light-weight IRC client. Set up user name (default being the
account name).

    /SET user_name $USER_NAME

Set up a nickname.

    /nick $NICKNAME

Add a network (automatic identification with NickServ):

    /NETWORK ADD -autosendcmd "/msg NickServ identify $PASSWORD" $NETWORK_NAME

It is always possible to add a dedicated name to a network later on.

    /NETWORK ADD -user $USERNAME $NETWORK_NAME

Adding a server to connect to (connect automatically to it when launching
irssi, no password needed here in the case of freenode as authentication
is done at the network level):

    /SERVER ADD -auto -network $NETWORK_NAME irc.example.com 6667

Example:

    /SERVER ADD -auto -network Freenode irc.freenode.net 6667

List servers:

    /SERVER list

Remove a server.

    /SERVER REMOVE irc.example.com

Adding a channel (automatically join).

    /CHANNEL ADD -auto #channel $NETWORK_NAME

Example:

    /CHANNEL ADD -auto #postgresql Freenode

Remove a channel.

    /CHANNEL REMOVE $CHANNEL $NETWORK_NAME

Example:

    /CHANNEL REMOVE #postgresql devnet

Some other things:

  * Ctl-P/Ctl-N to switch windows

Some notes for Freenode: here are [some steps]
(http://www.wikihow.com/Register-a-User-Name-on-Freenode) about how to
register a nickname in freenode.

Register a new account (need to choose previously an account name with
/nick):

    /msg nickserv register $PASSWORD $EMAIL

Drop a nickname on an account:

    /msg NickServ UNGROUP $NICK_TO_REMOVE

Drop an account.

    /msg NickServ DROP $USER $NAME

### screen

Using screen can be a good deal to when keeping a server online. Create
a new screen.

    screen -S $NAME
    irssi

Reattach to a detach screen.

    screen -r $NAME

List screens currently active.

    screen -list
