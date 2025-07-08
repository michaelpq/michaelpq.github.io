---
author: Michael Paquier
date: 2025-07-07 14:14:18+00:00
layout: page
type: page
slug: flamegraph
title: PostgreSQL - FlameGraph
tags:
- postgres
- postgresql
- performance
- cpu

---

FlameGraph is a utility tool able to produce pictures of profiles,
for example taken with perf.  First close the upstream repository
with the following command:

    git clone https://github.com/brendangregg/FlameGraph flamegraph

Then, after taking a perf profile, with output generated to a file or
another, it is possible to use this command to write the call stacks
to a dedicated file:

    perf script -i profile.perf > profile.stacks

Generating an image of these stacks can be achieved with the following
two commands, both in the git repository cloned above.  First, the call
stacks are aggregated, so that the time spent in similar call stacks is
summed up:

    ~/git/flamegraph/stackcollapse-perf.pl profile.stacks > profile.folded

Then an image can be created:

    ~/git/flamegraph/flamegraph.pl profile.folded > profile.svg

Differential flame graphs can be also very useful to compare two profiles,
for example these taken with a patch and a stable branch:

    ~/git/flamegraph/difffolded.pl head_profile.folded patch_profile.folded | \
	    ~/git/flamegraph/flamegraph.pl > profile_diff.svg

Then this .svg can be opened in a browser and it is possible to use a
cursor to check details about the aggregated stacks.
