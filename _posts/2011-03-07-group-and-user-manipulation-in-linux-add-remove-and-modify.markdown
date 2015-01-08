---
author: Michael Paquier
lastmod: 2011-03-07
date: 2011-03-07 07:59:37+00:00
layout: post
type: post
slug: group-and-user-manipulation-in-linux-add-remove-and-modify
title: 'Group and user manipulation in Linux: Add, remove and modify'
categories:
- Linux-2
tags:
- add
- foo
- group
- groupadd
- groupdel
- hierarchy
- hoge
- linux
- modify
- remode
- useradd
- userdel
- usermod
---

Here are a couple of useful commands that may help you to manipulate users and group in a Linux environment.

Groups are useful when to want multiple users to share some areas among them, while users not in the group won't have an access to the shared space.
It helps in building a hierarchy in a Linux system.

When you create a new user, a new group is also created with him.

    useradd $USER

You can use the command "id" to check the groups of a user.
Here a new user hoge is created.

    root@boheme:/etc# id hoge
    uid=1003(hoge) gid=1004(hoge)
    root@boheme:/etc# useradd hoge
    root@boheme:/etc# cat /etc/group | grep hoge
    hoge:x:1004:

In the case of adding a new user immediately in a primary group, you can use:

    useradd -g $GROUP $USER

Here is an example:

    root@boheme:/etc# groupadd foo
    root@boheme:/etc# useradd -g foo hoge
    root@boheme:/etc# id hoge
    uid=1003(hoge) gid=1003(foo) groups=hoge(1003)

So here user hoge has been created and has foo as primary group.

You can also add secondary groups to a user, with the option "-G".

    usermod -G $GROUP $USER

Here is an example:

    root@boheme:/etc# groupadd foo2
    root@boheme:/etc# usermod -G foo2 hoge
    root@boheme:/etc# id hoge
    uid=1003(hoge) gid=1003(foo) groups=1003(foo),1004(foo2)`

Here, user hoge has been added to the group foo2, and his primary group has not changed.

You can also remove a user from secondary group with:

    gpasswd -d $USER $GROUP

