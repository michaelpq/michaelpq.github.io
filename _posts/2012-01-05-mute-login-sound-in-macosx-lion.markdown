---
author: Michael Paquier
lastmod: 2012-01-05
date: 2012-01-05 04:16:53+00:00
layout: post
type: post
slug: mute-login-sound-in-macosx-lion
title: Mute login sound in MacOSX Lion
categories:
- MacOS
tags:
- bash
- hook
- lion
- login
- macbookair
- macbookpro
- machine
- macos
- macos 10.7
- macosx
- mute
- sound
---

In system preferences of MacOS Lion, there is no way to disable the disturbing login sound.
This is particularly annoying because the login sound can be heard even if there are earphones are plugged in your machine.

However, there is a workaround for that but playing but MacOS hooks when logging in a window and using the command [osascript](http://developer.apple.com/library/mac/#documentation/Darwin/Reference/ManPages/man1/osascript.1.html) (used to launch MacOS related scripts).
You need first to create two small bash scripts that use osascript to enable and disable sound.

Let's create the first one called sound\_disable.sh with the following code. It can be launched to disable the sound of your machine.

    #!/bin/bash
    osascript -e 'set volume without output muted'

The second script is close to that, let's call it sound\_enable.sh with the following code. It can be launched to enable the sound of your machine.

    #!/bin/bash
    osascript -e 'set volume with output muted'

The next step is to launch those two scripts when your machine is being launched and switches to the login window. In order to do that, you can use the MacOS-related hook called com.apple.loginwindow. You can check if a hook is already set with those commands:

    sudo defaults read com.apple.loginwindow LoginHook
    sudo defaults read com.apple.loginwindow LogoutHook

Then do the following as root. What remains is to place the scripts you created into a place where the hook will launch them.  Let's say you place them in $HOOK\_FOLDER. For example, this can be in /etc/ or whatever you like. Then you have to grant execute permission on those files.

    chmod +x $HOOK_FOLDER/sound_enable.sh
    chmod +x $HOOK_FOLDER/sound_disable.sh

The last thing you need to do is to set up the hook to launch the script when login window appears, and re-enable it once you have logged in your machine.

    sudo defaults write com.apple.loginwindow LogoutHook $HOOK_FOLDER/sound_disable.sh
    sudo defaults write com.apple.loginwindow LoginHook $HOOK_FOLDER/sound_enable.sh

And you're done.
