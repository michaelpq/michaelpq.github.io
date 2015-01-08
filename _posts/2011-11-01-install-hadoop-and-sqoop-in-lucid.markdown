---
author: Michael Paquier
lastmod: 2011-11-01
date: 2011-11-01 03:56:49+00:00
layout: post
type: post
slug: install-hadoop-and-sqoop-in-lucid
title: Install Hadoop and Sqoop in Lucid
categories:
- Linux-2
tags:
- debian
- hadoop
- hbase
- intall
- lucid
- memo
- postgresql
- sqoop
- test
- ubuntu
---

This is a short memo to install Hadoop and sqoop (Hadoop interface with db backend) in Ubuntu Lucid.

First it is necessary to add the following debian repository from Cloudera, the host of Hadoop and sqoop.
This can be added from System -> Update manager -> Settings (bottom-left) -> Other sources (tab) -> add.

    deb http://archive.cloudera.com/debian -cdh3 contrib

On Lucid,  has to be replaced by lucid, giving:

    deb http://archive.cloudera.com/debian -cdh3 contrib

A Java environment is necessary, you should have at least default-jdk 1.6.
Then install the software itself:

    sudo apt-get install hadoop
    sudo apt-get install sqoop
    sudo apt-get install hadoop-hbase

Once trying to launch sqoop on certain tables through PostgreSQL, you may find the following error:

    sqoop import --table test --connect jdbc:postgresql://localhost/postgres --verbose
    ...
    ERROR sqoop.Sqoop: Got exception running Sqoop: java.lang.RuntimeException: Could not load db driver class: org.postgresql.Driver`

This means that JDBC driver of PostgreSQL is not installed correctly.
You have to download it from [here](http://jdbc.postgresql.org/).
Then copy it in /usr/lib/sqoop/.

More details about the installation can be found here.
