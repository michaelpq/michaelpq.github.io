---
author: Michael Paquier
date: 2016-09-09 14:07:09+00:00
layout: page
type: page
slug: thinkpad
title: 'Linux - Thinkpad'
tags:
- linux
- thinkpad
- trackpoint
- scrolling
- sound
- install
- settings
- keyboard
- brightness

---

Here are some settings specific for any Thinkpads.

### Kernel module

The Linux kernel comes up with a specific module that greatly eases things.
Just do the following to enable it:

    $ cat /etc/modules-load.d/x260.conf
    # Load events for Thinkpad x260
    thinkpad_acpi

### Fn keys

Volume and brightness keys are not enabled by default. This needs to be
set using ACPI events that tracks keyboard events to work on the power
management of the machine. First install the package acpi (may vary
depending on the distribution).

Using acpi_listen is also useful to look at the events generated. Once
those events are found out, it is then necessary to register a set of
actions in /etc/acpi/, with their mapping events.

## Fonts for browsers

Some browers prefer to have some additional fonts installed to work
properly, like

  * ttf-dejavu, normal characters for code quote.
  * ttf-sazanami, Japanese characters.
