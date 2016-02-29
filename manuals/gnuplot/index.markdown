---
author: Michael Paquier
date: 2011-02-28 13:01:45+00:00
layout: page
type: page
slug: gnuplot
title: Manual for GNUplot
tags:
- gnuplot
- manual
- graph
- plot
- line
- test
- memo
- multiple
- smooth

---

Setting up a terminal is necessary to determine how the data format output.
One useful terminal is for example jpeg or png, that can be set as follows:

    set terminal png
    set terminal jpeg

Then setting up the output location:

    set output "/to/path/output_pix.png"

Here are some commands for the layout of the graph:

    set xlabel "TPS (tx/s)"
    set ylabel "Time (s)"
	set title "pgbench blah"

Plotting some data (specifying multiple outputs is fine):

    # lt = line type, 1 is full
    # lc = line color
	# pt = point typle, 0 is none
	# with linespoint, join points in a single line
    plot "/to/data/path/data.txt" title "Some data" lt 1 pt 0 with linespoint

To reset a picture, simply remove the output location and recreate it:

    !rm "/to/path/output_pix.png"
    set output "/to/path/output_pix.png"
