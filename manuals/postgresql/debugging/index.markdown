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

When debugging something that happens at session startup, here are some
settings that can be used to delay startup for a couple of seconds, enough
to attach breakpoints to the process tested.

    PGOPTIONS="-W n"
