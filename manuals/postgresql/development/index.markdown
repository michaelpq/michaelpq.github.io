---
author: Michael Paquier
date: 2014-03-09 14:14:18+00:00
layout: page
type: page
slug: development
title: PostgreSQL - Development
tags:
- postgres
- postgresql
- development
- documentation
- programming
- compilation

---

### Documentation

On Archlinux, compiling the documentation requires the following packages:

    docbook
    docbook2x
    docbook-dsssl
    docbook-xsl
    openjade

With that, everything should be set up and ready to go, SGML catalogs are
as well set correctly via the package openjade. Using jade may result in
crashes, so avoid that at all costs.
