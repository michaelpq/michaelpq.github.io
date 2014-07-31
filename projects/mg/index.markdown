---
author: Michael Paquier
date: 2014-07-31 13:10:48+00:00
layout: page
type: page
slug: mg
title: 'mg'
tags:
- editor
- emacs
- mg
- light
- weight
- custom
- fork
- easy
- development
- community
- development
- bug
- maintenance
- project
---
[mg](https://github.com/michaelpq/mg) is an emacs-like light-weight editor,
formerly named MicroGnuEmacs. For my own needs and to improve its portability,
I have been hacking it a bit, finishing with a fork of it that has a couple
of modifications:

  * Use of 4-space tab by default
  * Removal of ctags support to remove dependency on clens
  * Update of BSD-related functions to more global things
   * strtonum to strtol
   * strlcat and strlcpy managed using a dedicated port file
   * fgetln to getline

This code can be fetched with the following command:

    git clone https://github.com/michaelpq/mg.git
