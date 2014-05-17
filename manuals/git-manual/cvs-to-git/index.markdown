---
author: Michael Paquier
date: 2012-05-11 00:44:03+00:00
layout: page
type: page
slug: cvs-to-git
title: CVS to GIT
tags:
- michael
- paquier
- developer
- cvs
- migration
- git
- transfer
- package
- cvsimport
---
Transferring a CVS repository to a GIT one is pretty simple.

You need first to install the following packages: git-cvs cvsps. In
ArchLinux, git-cvs is lacking of support in ArchLinux, so I used an
RPM-based box.

    yum install git-cvs cvsps

Then, simply run the following command in a given folder $FOLDER.

    mkdir $FOLDER
    cd $FOLDER
    git cvsimport -v -d :pserver:anonymous@example.com:/sources/classpath \
        $MODULE_NAME
