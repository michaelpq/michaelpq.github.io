---
author: Michael Paquier
date: 2013-07-19 07:05:18+00:00
layout: page
type: page
slug: submodules
title: 'submodules in git'
tags:
- git
- manual
- paquier
- michael
- help
- submodule
- initialization
- update
- manage
---

A submodule consists of a soft link in a Git repo to another repository, defined on parent by a path and a commit ID. Since git 1.8.3, a branch can as well be given to synchronize a submodule based on the latest commit of a branch.

#### Initialization

This is recommended:

    git submodule update --init --recursive

#### Automatic update after checkout

Create the file .git/hooks/post-checkout with this content.

    #!/bin/bash
    # Update submodules after a branch checkout
    CURRENT_FOLDER=`pwd`

    # Move to the root of this folder
    cd `git rev-parse --show-toplevel`

    # After a checkout, enforce an update of submodules for this folder
    git submodule update --init --recursive

    # Move back to current folder
    cd $CURRENT_FOLDER
