---
author: Michael Paquier
comments: true
date: 2011-11-29 00:29:06+00:00
layout: post
type: post
slug: solve-key-input-issues-with-minecraft-on-linux
title: Solve key-input issues with minecraft on Linux
wordpress_id: 650
categories:
- Linux
- Minecraft
tags:
- character
- chinese
- ibus
- input
- issue
- japanese
- killall
- korean
- linux
- minecraft
- play
- wait
---

When trying to launch Minecraft, you may notice that the key-input is not working properly, leading to a character that cannot move but only interact with blocks around him. This issue is related to ibus, which is used as a character input client for Chinese, Japanese and Korean among others.

In order to solve that, you need to kill ibus during the time Minecraft is launched.
I think you already downloaded the game client minecraft.jar from dedicated website. Then save it in a folder called $FOLDER. Here $FOLDER=$HOME/bin/java.

Then use this script to launch minecraft.

    #!/bin/bash
    #Minecraft launcher
    #This is here to solve issues with key input in linux systems

    #Kill the ibus daemon
    killall ibus-daemon

    #Launch minecraft
    java -Xmx1024M -Xms512M -cp $HOME/bin/java/minecraft.jar net.minecraft.LauncherFrame &
    MINECRAFT_PID=$!
    sleep 1

    #Then wait for minecraft to finish before relaunching ibus.
    ibus-daemon -d
    wait $MINECRAFT_PID

You can still use character input as normal in other windows or terminals. What is also possible is to create an application launcher on a panel launching this script, and then you can directly launch minecraft without going through a terminal.
