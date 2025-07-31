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

### Enforce wait

When debugging something that happens at session startup, here are some
settings that can be used to delay startup for a couple of seconds, enough
to attach breakpoints to the process tested.

    PGOPTIONS="-W n"

### Compiling test programs

Here is a single commands to compile code file into an executable:

    gcc hello_world.c -o hello_world_exec

To generate a .so file:

    gcc -c -fPIC hello_world.c -o hello_world.o
    gcc hello_world.o -shared -o libhello.so

Or in one step:

    gcc -g -Wall -shared -o libhello.so -fPIC hello.c

When generating a library for a test, LD_PRELOAD can be useful to load
this test library before any other:

    LD_PRELOAD=/path/to/library/libhello.so my_command $ARGS

### valgrind

valgrind is useful to find memory problems in Postgres, try to use with
something like the attached.

    valgrind \
        --suppressions=$PG_SOURCE/src/tools/valgrind.supp \
        --trace-children=yes --track-origins=yes --read-var-info=yes \
		--leak-check=full --log-file=$PGDATA/valgrind.log \
        postgres -D $PGDATA

### Corrupting pages

A way to manually corrupt data may be to use dd like that, notrunc being
really important to not truncate the relation file once a block is changed:

    dd if=/dev/random bs=8192 count=1 \
        seek=$BLOCK_ID of=base/$DBOID/$RELFILENODE
        conv=notrunc

### Encoding

Here is a small trick to write directly in UTF-8 using raw data. For example
for sequence c2 a2 (cent sign):

    =# SELECT E'\xc2\xa2' AS "char";
     char
    ------
     c
    (1 row)

### Data structures

pahole, which is part of the dwarf utilities, is useful to see the size
of structures using compiled files.

    pahole source.o class_name
