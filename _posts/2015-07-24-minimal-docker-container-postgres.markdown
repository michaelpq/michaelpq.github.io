---
author: Michael Paquier
lastmod: 2015-07-24
date: 2015-07-24 05:24:38+00:00
layout: post
type: post
slug: minimal-docker-container-postgres
title: 'Minimalistic Docker container with Postgres'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- highlight
- feature
- container
- virtual
- machine
- docker
- development
- xlc
- alpine
- arm
- architecture

---

Docker is well-known, is used everywhere, is used by everybody and is a
nice piece of technology, there is nothing to say about that.

Now, before moving on with the real stuff, note that for the sake of
this ticket all the experiments done are made on a Raspberry PI 2, to
increase a bit the difficulty of the exercise and to grab a wider
understanding of how to manipulate Docker containers and images at a rather
low level per the reasons of the next paragraph.

So, to move back to Docker... It is a bit sad to see that there are not many
container images based on ARM architectures even if there are many machines
around. And also, the size of a single container image can reach easily a
couple of hundred megabytes in its most simple shape (it does not change
the fact that some of those images are very popular, so perhaps the author
of this blog should not do experimentations on such small-scale machines
to begin with).

Not all the container images are that large though, there is for example
one container based on the minimalistic distribution [Alpine Linux]
(http://alpinelinux.org/), with a size of less than 5MB. Many packages
are available as well for it so it makes it a nice base image for more
extended operations. Now, the fact is that even if Alpine Linux does publish
deliverables for ARM, there are no Docker container around that make
use of it, and trying to use a container image that has been compiled for
example x86_64 would just result on an epic failure.

Hence, extending a bit a script from the upstream
[Docker facility of Alpine Linux](https://github.com/gliderlabs/docker-alpine),
it is actually easily possible to create from scratch a container image
able to run on ARM architectures (the trick has been to consider the fact
that Alpine Linux publishes its ARM deliverables with the alias armhf).
Note in any case the following things about this script:
- root rights are needed
- ARM environment needs to be used to generate an ARM container
- the script is [here](https://raw.githubusercontent.com/michaelpq/pg_plugins/master/docker/mkimage-alpine.sh)
Roughtly, what this script does is fetching a minimal base image of
Alpine Linux and then importing it in an image using "docker import".

Once run simply as follows, it will register a new container image:

    $ ./mkimage-alpine.sh
    [...]
    $ docker images
    REPOSITORY          TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
    alpine-armv7l       edge                448a4f53f4df        About an hour ago   4.937 MB
    alpine-armv7l       latest              448a4f53f4df        About an hour ago   4.937 MB

The size is drastically small, and comparable to the container image
already available in the Docker registry. Now, moving on to things regarding
directly Postgres: how much would it cost to have a container image able
to run Postgres?  Let's use the following Dockerfile and get a look at it
then (file needs to be named as Dockerfile):

    $ cat Dockerfile_postgres
    FROM alpine-armv7l:edge
    RUN echo http://nl.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories && \
    apk --update && \
    apk add shadow postgresql bash

Note that here the package shadow is included to have pam-related utilities
like useradd and usermod as Postgres cannot run as root, and it makes life
simpler (and shadow is only available in the repository testing). After
building the new container image, let's look at its size:

    $ docker build -t alpine-postgres .
    [...]
    $ docker images
    REPOSITORY          TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
    alpine-postgres     latest              3bcc06a7ce79        2 hours ago         23.46 MB
    alpine-armv7l       edge                448a4f53f4df        2 hours ago         4.937 MB
    alpine-armv7l       latest              448a4f53f4df        2 hours ago         4.937 MB

Without bash this gets down to 22.55 MB, and without shadow + bash its
size is 20.86 MB. This container image includes only the necessary binaries
and libraries to be able to run a PostgreSQL server, and does nothing to
initialize it or configure it. Let's use it then and create a server:

    $ docker run -t -i alpine-postgres /bin/bash
    # useradd -m -g wheel postgres
    # su - postgres
    $ initdb -D data
    [...]
    $ pg_ctl start -D data
    $ psql -At -c 'SELECT version();'
    PostgreSQL 9.4.4 on armv6-alpine-linux-muslgnueabihf, compiled by gcc (Alpine 5.1.0) 5.1.0, 32-bit

And things are visibly working fine. Now let's look at how much space would
consume a development box for Postgres as a container image, and let's use
the following Dockerfile spec for this purpose with some packages needed to
compile and work on the code:

    FROM alpine-armv7l:edge
    RUN echo http://nl.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories && \
    apk update && \
    apk add shadow bash gcc bison flex git make autoconf

Once built, this gets larger to 125MB, but that's not really a surprise...

    $ docker build -t alpine-dev .
    [...]
    $ docker images
    REPOSITORY          TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
    alpine-dev          latest              15dc9934cc36        16 minutes ago      125 MB
    alpine-postgres     latest              3bcc06a7ce79        About an hour ago   23.46 MB
    alpine-armv7l       edge                448a4f53f4df        About an hour ago   4.937 MB
    alpine-armv7l       latest              448a4f53f4df        About an hour ago   4.937 MB

All the files and Dockerfile specs have been pushed [here]
(https://github.com/michaelpq/pg_plugins/tree/master/docker). Feel free
to use them and play with them.
