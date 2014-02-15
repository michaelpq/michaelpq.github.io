---
author: Michael Paquier
comments: true
date: 2012-06-21 07:42:43+00:00
layout: post
type: post
slug: avoid-escape-characters-in-git
title: Avoid escape characters in GIT
wordpress_id: 1050
categories:
- Linux-2
tags:
- avoid
- character
- configuration
- diff
- escape
- git
- less
- log
- more
- output
- pager
- program
---

In GIT you may finish with a bunch of escape characters (ESC) when invocating colors for "git log" and "git diff".

    ESC[31m-{ESC[m
    ESC[31m-    Oid         res = InvalidOid;ESC[m
    ESC[31m-    Relation    rel;ESC[m
    ESC[31m-    StringInfo  buf;ESC[m
    ESC[31m-    char       *storageName = NULL;ESC[m
    ESC[31m-    int         prefix = 0;ESC[m
    ESC[31m-ESC[m

This is due to the default pager which is "less", because it cannot interpret correctly the escape characters.
There are a couple of ways to avoid that.

The first one is to change the pager to "more".

    git config --global core.pager more

The second one is to append an additional command with "less -r".

    git diff --color | less -r
    git log -p --color | less -r

And you get a nice colored output.

Here is another solution which is more portable to my mind, and it is the one I use.

    git config --global core.pager "less -r"

This directly appends the modified less command when git pager is invocated to print correctly escape characters.
