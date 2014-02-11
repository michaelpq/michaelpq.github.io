---
author: Michael Paquier
comments: true
date: 2011-10-21 06:05:25+00:00
layout: post
slug: compile-documentation-in-postgres
title: Compile documentation in postgres
wordpress_id: 578
categories:
- PostgreSQL-2
tags:
- '10.04'
- docbook
- documentation
- html
- lucid
- man
- pdf
- postgres
- postgresql
- sgml
- ubuntu
---

After a couple of hours fighting, I finally went through a way to compile documentation of postgres under Ubuntu Lucid.

For man pages and html, you need the following packages.

    docbook-xsl
    docbook
    docbook2x
    docbook-dsssl
    jade

Then, before running configure, the following setup is necessary:

    export DOCBOOKSTYLE=/usr/share/sgml/docbook/stylesheet/dsssl/modular

Compilation of html pages need the following command in doc/src/sgml:

    make html

Result is then found in doc/src/sgml/html.

Compilation of man pages need the following command in doc/src/sgml:

    make man

Result is then found in doc/src/sgml/manX. X being 1, 3 or 7. 

Then when compiling the code for pdf documentation, the following package is required.

    pdfjadetex

Be aware that this had dependencies with tex, and several packages.

Compilation of pdf is done with the following command:

    make postgres-A4.pdf

However, pdf compilation still shows issues due to incorrect parameters in /etc/texmf/texmf.cnf.

    hash_extra = 50000
    hash_size.mpost = 120000
