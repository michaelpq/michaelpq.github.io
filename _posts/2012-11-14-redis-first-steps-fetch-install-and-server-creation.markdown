---
author: Michael Paquier
comments: true
lastmod: 2012-11-14
date: 2012-11-14 14:30:15+00:00
layout: post
type: post
slug: redis-first-steps-fetch-install-and-server-creation
title: 'Redis: first steps, code fetch, install and server creation'
categories:
- redis
tags:
- brew
- bsd
- database
- fetch
- git
- install
- key
- make
- open source
- pacman
- redis
- server
- store
- value
---
[Redis](http://redis.io/) is an open source project providing key/value store features in a database server. This means that basically you can store in the database a value that has a given key and then retrieve the value using its key.
It supports advanced data types like strings, lists (elements sorted by insertion order), sets (unordered collection of elements) and sorted sets (collection of elements ordered by a key given by user). There are also other things supported like hashes or atomic integer incrementation. Feel free to have a look at the [documentation](http://redis.io/documentation) about that.

This post will not deal with advanced aspects of Redis: this will be the subject of other articles. What is going to be described here is how to get Redis, run a server and then perform some simple operations.

Redis is honestly a famous project (5,000 followers on Github), so I am sure you will be able to install it easily whatever your environment.
For example, in the case of Archlinux, you only need to use a simple pacman command.

    pacman -S redis

For CentOS:

    yum install redis

But you honestly feel more what you do if you compile and install the code yourself from [Github](https://github.com/antirez/redis) for example. So let's get the code.

    mkdir $REDIS_CODE
    cd $REDIS_CODE
    git init
    git remote add origin https://github.com/antirez/redis.git
    git fetch origin
    git checkout unstable

The unstable branch is the main development branch, similar to master in the case of [postgresql](https://github.com/postgres/postgres). You can refer to other branches for stable releases like 2.6 or 2.8.

The server code is located in folder src/, but you first need to compile the dependencies or you will get errors of the following type:

    $ make
    clang: error: no such file or directory: '../deps/hiredis/libhiredis.a'
    clang: error: no such file or directory: '../deps/lua/src/liblua.a'
    make[1]: *** [redis-server] Error 1
    make: *** [all] Error 2

So here be sure to install first the dependencies as below.

    cd deps
    make lua hiredis linenoise

Then finalize compilation.

    cd $REDIS_CODE/src
    make

Finally install the binaries in a wanted folder.

    make PREFIX=$REDIS_INSTALL install

Once installed, you will notice several binaries but the most important ones are redis-server (used to boot a server) and redis-cli (client to connect to a server).

In order to launch a server on default port 6379, simply launch this command, assuming that $REDIS_INSTALL is included in PATH:

    redis-server

A Redis server can use a configuration file when booted, which can be specified like this:

    redis-server /path/to/conf/redis.conf

There is also a template of redis.conf in the root tree of source code.

All the options of redis.conf can be specified via command line, here are some of them I find pretty useful for beginners.

  * --dir $DIR, to specify the directory where database dump file or log files are written to. The default value is "./", so all the files are written in this case in the folder where redis-server is launched. I personally find that not really intuitive but...
  * --port $PORT\_NUMBER, port number where server listens to. Default is 6379.
  * --logfile, name of file where logs are written. Default is stdout. Once again here I recommend using a clear file name combined with --dir to bring clarity to your database servers.

Then, in order to connect to the server, simply use redis-cli (see redis-cli --help for details about the options).

    $ redis-cli
    redis 127.0.0.1:6379>

Then you are ready to operate on your server. Let's do here a simple get/set.

    redis 127.0.0.1:6379> set foo bar
    OK
    redis 127.0.0.1:6379> get foo
    "bar"

A last thing, I quickly wrote two scripts in case you are interested:

  * redis\_compile, script that can be used to compile code, perform tests and do some other tricks
  * redis\_start, script that can be used to set up a Redis cluster with master and slaves

Please note that those scripts do not have the granularity necessary for a use in production and they are only dedicated to development.

I have not yet discussed about the numerous features of Redis like things related to the cluster structure (master/slave replication, memory management), or data structures (lists, sets), but they will be covered in some future posts.
