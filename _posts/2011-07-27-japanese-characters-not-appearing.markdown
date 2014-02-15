---
author: Michael Paquier
comments: true
date: 2011-07-27 07:36:00+00:00
layout: post
type: post
slug: japanese-characters-not-appearing
title: 'Japanese characters not appearing on PDF in Ubuntu '
wordpress_id: 439
categories:
- Linux-2
tags:
- character
- japanese
- kanji
- life
- linux
- pdf
- poppler-data
- print
- save
- ubuntu
---

This command may simply save your life:

    apt-get install poppler-data

It installs the package poppler-data to allow your laptop to show Japanese characters on PDF.
You still may have problems with fonts though.
