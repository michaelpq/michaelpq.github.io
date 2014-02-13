---
author: Michael Paquier
date: 2012-08-04 05:51:05+00:00
layout: page
type: page
slug: home
title: 'Home, user environment managed as a GIT repo'
tags:
- home
- michael
- paquier
- bash
- script
- spatch
- emacs
- irssi
---
I manage my own Linux home as a GIT repository adapted for multiple environments.

It contains emacs, bash cnfiguration (bash alias, etc.) and scripts used for PostgreSQL development and other extra things.
All the repositories that need to be kept private are simply ignored, allowing to keep a mobile and flexible environment that needs just to be fetched to be set up. This is particularly useful to deploy development VMs at critical speed. Settings can also be kept private with some dedicated configuration files that can be hidden from the remote repository.

Home comes as well with a module called spatch, able to manage multiple private user profiles within a single user session. This is useful when switching profiles within a single machine when it is not possible to have VMs at disposition. Default and example profiles are available in .spatch.d/. Configuration file templates for many purposes are available in .examples (irssi, mpd, gitconfig, etc.).

The GIT repository is available in github as [michaelpq/home](http://github.com/michaelpq/home).

You can fetch it directly with one of those commands;

    git clone https://github.com/michaelpq/home.git
    git://github.com/michaelpq/home.git

Pull requests and issue reports are accepted.
