---
author: Michael Paquier
comments: true
date: 2012-03-09 15:53:24+00:00
layout: post
slug: clean-up-dos-files-with-emacs
title: Clean up dos files with emacs
wordpress_id: 850
categories:
- Linux
tags:
- clean
- dos
- file
- fix
- format
- linux
- text
- undecided
- unix
- windows
---

When creating files in Windows, those files will have the DOS format.
This creates annoying ^M characters at the end of lines, which can be seen in patches or diff files.

In order to localize them, use this command:

    find . -not -type d -exec file "{}" ";" | grep CRLF

It will give an output like this for dos files:

    ./example.txt: ASCII text, with CRLF line terminators

Then open them in emacs, and launch that command:

    M-x set-buffer-file-coding-system RET undecided-unix

M-x means escape and X. RET is return.
Then save your file and you are done.

