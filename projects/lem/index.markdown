---
author: Michael Paquier
date: 2014-07-31 13:10:48+00:00
layout: page
type: page
slug: lem
title: 'lem'
tags:
- editor
- emacs
- lem
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
[lem](https://github.com/michaelpq/lem) is an emacs-like light-weight editor,
based on mg. For my own needs and to improve its portability and it maintenance
I have been hacking it a bit, finishing with a fork of it that has a couple
of modifications:

  * Use of 4-space tab by default
  * Removal of independent extensions, removing dependency on clens
  * Update of BSD-related functions to more global things
   * strtonum to strtol
   * strlcat and strlcpy managed using a dedicated port file
   * fgetln to getline

This code can be fetched with the following command:

    git clone https://github.com/michaelpq/lem.git
