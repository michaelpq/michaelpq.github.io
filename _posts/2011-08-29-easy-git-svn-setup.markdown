---
author: Michael Paquier
comments: true
lastmod: 2011-08-29
date: 2011-08-29 02:10:09+00:00
layout: post
type: post
slug: easy-git-svn-setup
title: Easy GIT svn setup
categories:
- Linux-2
tags:
- central
- fetch
- git
- git-svn
- interaction
- linux
- local
- rebase
- repository
- subversion
- svn
- url
---

GIT is nice for its portability.
Here is a short memo in case you want to export a SVN (Subversion) repository into a GIT environment.

You need first to install the package git-svn and subversion.

First initialize your local repository.

    mkdir foo
    cd foo
    git init

Then setup the repository to fetch the svn URL you are looking for. I found that the easiest solution to check out a SVN repository was by playing with the local repository configuration to get a remote svn repository.

    git config --add svn-remote.$SVN_REPO.url http://url/to/check/out
    git config --add svn-remote.$SVN_REPO.fetch :refs/remotes/$SVN_REPO
    git svn fetch $SVN_REPO [-r$REV_NUMBER]
    git svn rebase $SVN_REPO

SVN\_REPO is the identifier you want to associate with your local repository.
REV\_NUMBER can be added to specify a version number to check out.
What happens here is that the SVN repository is checked out as a remote branch.

    ~/code/test(master) $ git branch -a
    * master
      remotes/$SVN_REPO

Once this is done, you can use your local copy and check that in a central git repository or merge that with other works.

When SVN has to go through a proxy, it is important to set the file ~/.subversion/servers with the following options.

    http-proxy-host = proxy.server.com
    http-proxy-port = 8080
