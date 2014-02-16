---
author: Michael Paquier
comments: true
lastmod: 2011-11-18
date: 2011-11-18 14:23:31+00:00
layout: post
type: post
slug: script-to-replace-string-with-sed
title: Script to replace string with sed
wordpress_id: 644
categories:
- Linux-2
tags:
- bash
- extension
- for
- linux
- replace
- script
- sed
- string
- strreplace
- word
---

Here is a short script to replace strings with sed easily written in bash.

    #!/bin/bash
    #Replace string in file of given extension
    #argument 1, extension type
    #argument 2, old string 
    #argument 3, new string
    EXPECTED_ARGS=3

    if [ $# -ne $EXPECTED_ARGS ]
    then
        echo "Usage: `basename $0` [extension] [old_str] [new_str]"
        echo "Exemple: `basename $0` php old_text new_text"
        exit 1
    fi

    EXTENSION=$1
    OLDSTR=$2
    NEWSTR=$3

    #Simply replace string with sed and erase old file
    for file in `find . -name "*.$EXTENSION"`
    do
        sed -i "s/$OLDSTR/$NEWSTR/g" $file
    done
    exit $?

The user can specify an extension, as well as the strings to be replaced and to replace.
This is just a memo, nothing serious...
