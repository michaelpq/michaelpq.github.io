---
author: Michael Paquier
date: 2011-02-28 13:06:25+00:00
layout: page
type: page
slug: gdb-manual
title: 'Manual for gdb'
tags:
- gdb
- debug
- manual
- beginner
- way
- doing
- help
- command
- essential
- experience
- linux
- osx
---
## GDB manual

  Young developpers are always facing problems with the use of debuggers. This manual is for them. It contains some simple tips and essential commands to survive with gdb. Some experienced users may also find a couple of useful tips here.

### Code preparation

To be visible with a debugger, your C code has to be compiled with a -g flag in CFLAGS. For instance by default PostgreSQL uses a optimisation 2 flag -O2 when compiled. To compile with a debug flag, refer to the application manuals, but usually it is necessary to set that in a Makefile.

    CFLAGS='-g'

### About breakpoints

A breakpoint is used to stop in a chosen place your program after launching it. It permits to check the state of the program and the process run, as well as values during a run. It is possible in GDB to set up a breakpoint at a line number or a chosen function name. Here is how to set a breakpoint at a line.

    break $FILE_NAME:$LINE_NUMBER

For instance

    break foo.cpp:100

sets a breakpoint at line 100 of the file called foo.cpp. Here is how to set a breakpoint for a function.

  break $FILE_NAME:$FUNCTION_NAME
  break $FUNCTION_NAME

If the function is unique in the program run, it is not even necessary to specify a file name. Make a breakpoint at a special object (C++ oriented)

    break $OBJECT::$METHOD

Display breakpoint information, their ID numbers and their settings.

    info breakpoints

Disable/enable a breakpoint with a chosen ID.

    enable $ID_NUMBER
    disable $ID_NUMBER

Here are a series of commands to clean up breakpoints. Clear Breakpoint in the code where program is run.

    clear

Delete all breakpoints, this will ask for confirmation.

    del

It is also possible to stop with a condition, based for example on a
numerical condition. A breakpoint on the line where this condition is
checked is still necessary though.

    b $C_FILE:$LINE_DEBUGGED
    condition 1 $OBJECT_NAME==$VALUE
    cond 1 $OBJECT_NAME==$VALUE

For strings, it can be a bit trickier, for example with a code like
that:

    1: while (true) {
    2:    char *data = getInputFromSource();
    3:    doActionWithSource(data);
    4: }

Here is how to stop at a breakpoint only for a given value of the
source, here simply "MyData".

    b foo.cpp:3
    set $my_data = "MyData"
    cond 1 strcmp($secret_code, c) == 0
    run

Makes the program stop when the object chosen has its value equal. It is also possible to use this functionnality with other operators.

###  3. About watchpoints

Cause the program to stop if $OBJECT_NAME value changes.

    watch $OBJECT_NAME

Cause the program to stop if $OBJECT_NAME is accessed (read or write).

    awatch $OBJECT_NAME

Cause the program to stop if $METHOD_NAME in the instance $INSTANCE_NAME is changed.

    watch $OBJECT_NAME.$METHOD_NAME

Cause the program to stop if $DATA in any instance of $OBJECT_NAME is changed. This will clear the watchpoint after stopping.

    watch $OBJECT_NAME::$DATA

### 4. Run an application

First launch an application.

    gdb $PROGRAM_NAME

This permits to launch gdb, but the application is not running yet. It is possible to set a couple of arguments to launch the application

    set args $ARG1 ... $ARGN

For instance, for a PostgreSQL initialization process.

    set args -D coord -h hostname

To run the application.

    run

Note: It is also possible (recommended!?) to enter breakpoints before running the application. If you got a Core file from a previous application crash, t is also possible associate an application with it. This is useful to analyze a crash circumstances

    gdb $PROGRAM_NAME $CORE_FILE
    gdb -c $CORE_FILE

If option -c is used to print out a core file, it is necessary to specify an application name and directory where code is to be able to view the code

    file $PROGRAM_NAME

### 5. Manipulate values

After launching GDB and the application properly, it is time to analyze the code. Print a value.

    print $OBJECT_NAME
    p $OBJECT_NAME

Print the value of a pointer or an array element.

    print $OBJECT_NAME[i]
    print *pointer

Print the return value of a function call. This can be used to determine values of any function. This prints the return value of strcmp:

    print strcmp( str1, str2 )

This can be used to determine values of any expression.

    print num1 < num2

Sometimes programs manipulate large buffers, here is how to read them once in a row.

    x/45s buffer->data

If you want to test a special condition, change the value of an object within the process. It overwrites the existing value.

    set $VARIABLE_NAME = $VALUE

### 6. Go through the code

Run the program until completion, or to the next breakpoint.

    continue
    c

Advance to the next source line.

    n

This will go into functions and treat each line there as another line. Or go down N lines in a row

    step N
    s N

This is similar to step, but it will not go into a function. 'next 10' will advance 10 lines.
    next
    n


This will run until the current stack frame returns. The value returned is printed.

    finish
    f

List the source code at your current location in the program. This permits to have a larger view of the code running through.

    list

### 7. Code visibility

Make coincide the core file with the application wanted.

    file $PROGRAM_NAME

Adds a folder containing code files, permits to view the code files in this folder.

    path $FOLDER_PATH

### 8. Multi-thread debugging

Attach gdb to a parent and fallback automatically to a new child forked.

    set follow-fork-mode child

### 9. Extras

Hitting enter with no command will repeat the last command. Most commands have one letter abbreviations.

    n => next
    c => continue
    s => step
    q => quit

The up arrow will recall old commands, just like bash or tcsh. There is help available, just type:

    help

Or if you want help on a specific command like break, type.

    help break

If you want to set certain breakpoints and watchpoints for a project, you can put the gdb commands in a file and start gdb with "-x filename". This will run those commands just like they were typed on the console.

If you run into problems with the name mangling,show the C style names for your class methods.

    nm
