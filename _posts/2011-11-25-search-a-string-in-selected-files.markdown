---
author: Michael Paquier
lastmod: 2011-11-25
date: 2011-11-25 03:20:03+00:00
layout: post
type: post
slug: search-a-string-in-selected-files
title: Search a string in selected files
categories:
- Linux-2
tags:
- bash
- case
- distinction
- extension
- file
- find
- linux
- script
- search
- strfind
- string
---

Here is a short script/memo to find strings inside given file.
The script is assumed to be called strfind. It is written in bash.

Here is the spec of this script.

    $ strfind ?
    Usage: strfind [-i] [filename] [string]
    Example: strfind "[hc]" text

You can then find strings with commands like:

    strfind *.c $TEXT_SEARCH

It is also possible to ignore case distinctions.

    strfind -i *.c $TEXT_SEARCH

So here is the script.

    #!/bin/bash
    #Find string strings in select file extension

    #Expected base arguments
    EXPECTED_ARGS=2
    IFLAG=0

    while getopts 'i' OPTION
    do
    case $OPTION in
        i)  #Track in repo all untracked files
            IFLAG=1
            #+1 base argument
            EXPECTED_ARGS=$(($EXPECTED_ARGS + 1))
            ;;
        ?)  echo "Usage: `basename $0` [-i] [filename] [string]"
            echo "Example: `basename $0` \"[hc]\" text"
            exit 0
            ;;
    esac
    done

    if [ $# -ne $EXPECTED_ARGS ]
    then
        echo "Usage: `basename $0` [-i] [filename] [string]"
        echo "Example: `basename $0` \"[hc]\" text"
        exit 1
    fi

    #Have only 2 or 3 arguments
    if [ "$EXPECTED_ARGS" = "2" ]
    then
        FILENAME=$1
        TXTSTRING=$2
    else
        FILENAME=$2
        TXTSTRING=$3
    fi

    #Print file name and line number
    OPTIONS="-Hn"

    #Don't care about large characters
    if [ "$IFLAG" = "1" ]
    then
        OPTIONS=$OPTIONS"i"
    fi

    #Execute command
    echo find . -name "$FILENAME" -exec grep $OPTIONS $TXTSTRING {} \;
    find . -name "$FILENAME" -exec grep $OPTIONS $TXTSTRING {} \;
    exit 0;
