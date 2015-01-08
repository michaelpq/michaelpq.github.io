---
author: Michael Paquier
lastmod: 2011-09-05
date: 2011-09-05 06:32:00+00:00
layout: post
type: post
slug: graphs-in-git
title: Graphs in GIT
categories:
- Linux-2
tags:
- alias
- command
- commit
- configuration
- git
- git-core
- graph
- log
---

In library git-core, git has a command that makes all the commits appearing in graphs.
For example:

    git log --graph --all

It is an other matter to make readable graphs. For that purpose, the following command is helpful to setup a special alias:

    git config alias.graph "log --graph --date-order -C -M --pretty=format:\"<%h> %ad [%an] %Cgreen%d%Creset %s\" --all --date=short"

This makes tags and branch names appear in green.

For a command without colors:

    git config alias.graph "log --graph --date-order -C -M --pretty=format:\"<%h> %ad [%an] %Cgreen%d%Creset %s\" --all --date=short"

Then this command based on the alias above prints nice-looking graphs.

    git graph
