---
author: Michael Paquier
date: 2014-09-20 05:13:59+00:00
layout: page
type: page
slug: linux
title: 'Linux - Coding'
tags:
- manual
- linux
- coding

---

## Data type lengths

On 32-bit and 64-bit machines, the length of the following standard
variables vary, here is a list of them with their associated length.

    Environment type  32 bit    64 bit
    short int         16 bit    16 bit
    int               32 bit    32 bit
    long int          32 bit    64 bit
    long long int     64 bit    64 bit
    size_t            32 bit    64 bit
    void*             32 bit    64 bit
