---
author: Michael Paquier
date: 2014-03-09 14:14:18+00:00
layout: page
type: page
slug: debugging
title: PostgreSQL - Debugging
tags:
- postgres
- postgresql
- debugging
- programming
- create
- patch
---
Here are a couple of things to know when programming with Postgres.

=== Enforce wait ===

When debugging something that happens at session startup, here are some
settings that can be used to delay startup for a couple of seconds, enough
to attach breakpoints to the process tested.

    PGOPTIONS="-W n"

=== Corrupting pages ===

A way to manually corrupt data may be to use dd like that, notrunc being
really important to not truncate the relation file once a block is changed:

    dd if=/dev/random bs=8192 count=1 \
        seek=$BLOCK_ID of=base/$DBOID/$RELFILENODE
        conv=notrunc
