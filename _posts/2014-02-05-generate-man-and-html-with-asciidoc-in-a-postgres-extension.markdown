---
author: Michael Paquier
lastmod: 2014-02-05
date: 2014-02-05 03:54:12+00:00
layout: post
type: post
slug: generate-man-and-html-with-asciidoc-in-a-postgres-extension
title: 'Generate man and html with asciidoc in a Postgres extension'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- pg_plugins
- documentation

---
When writing an [extension](https://www.postgresql.org/docs/devel/static/extend.html) or module for PostgreSQL, having proper regressions tests and documentation are important things (with actually useful features!) to facilitate its acceptance.

When it comes to [regressions](/postgresql-2/about-regression-tests-with-postgres-plug-in-modules/), PGXS comes up with the necessary infrastructure with mainly the variable REGRESS in Makefile, allowing an author to specify a list of tests that can be kicked with "make check" or "make installcheck". Using this flag has the advantage of relying on pg\_regress when it is necessary to compare expected and generated output, which is also something useful for alternative outputs on multiple platforms (like select\_having, select\_implicit or select\_views in regression tests of core).

In terms of documentation, it is possible to specify a list of raw files with the flag DOCS, that will install documentation in prefix/doc/$MODULEDIR (by default prefix is $PGINSTALL/share/, enforceable with -docdir in ./configure). Note that the list of Makefile variables of PGXS is [here](https://www.postgresql.org/docs/devel/static/extend-pgxs.html).

By experience, it incredibly facilitates the maintenance and the consistency of a project to have everything managed in a single place (tests, code and documentation), and it usually does not help a project to have a unique format of documentation. For example, having only a sole wiki or html pages on a web server as documentation might be good for short-term, but proves difficult in long-term if systems need to be migrated for example, and this doc might get easily out-of-sync with the code itself. Some people prefer using man pages, some html, and some others simple README thingies, and impacting the maximum number of users is important. Also, having everything centralized is a real time-saver especially when you are the only maintainer of a project. (As a side note, github actually manages that pretty well by helping people in managing documentation using a particular branch in their git repos, and have it appear automatically on a site, or directly with a dedicated git repository, even if it is easy to forget to update another branch or an additional git repository for the documentation).

DOCS makes somewhat difficult such centralized documentation management, and by experience I find it hard to manage a project with raw man pages or html pages as it takes time as well to put such things in a nice shape and understand it. However, what you can do is tricking DOCS by auto-generating extra documentation (each project maintainer has its own way to do as well!), and here is an example of how to do that with asciidoc. This is something that I have done for a small module called [pg\_arman](https://github.com/michaelpq/pg_arman) (Yes this name, somewhat close to its parent name, is for a fork, except that it is a light-weight version keeping only the necessary things, and dropping the weird stuff... That's another topic though). By the way, using asciidoc with xmlto has proved to facilitate the project maintenance and documentation readability for both html and man.

Controlling extra-documentation generation with asciidoc and xmlto can be controlled with some environment variables: for this example ASCIIDOC and XMLTO (incredible imagination). If one of those variables is not set, the extra-documentation will simply not be generated. A simple way to set them is to use that in for example bashrc (change it depending on your environment or build machine).

    export ASCIIDOC=asciidoc
    export XMLTO=xmlto

Or directly enforce those values with the make command.

    XMLTO=xmlto ASCIIDOC=asciidoc make USE_PGXS=1 [install]

The first one is better for developers, the second one better for automated builds.

Then, with all the documentation in doc/, generated from doc/pg\_arman.txt, here is how looks Makefile at the root of project for the documentation part.

    DOCS=doc/pg_arman.txt
    ifneq ($(ASCIIDOC),)
    ifneq ($(XMLTO),)
    man_DOCS = doc/pg_arman.1
    DOCS += doc/pg_arman.html doc/README.html
    endif # XMLTO
    endif # ASCIIDOC
 
    [extra process blabla]
 
    ifneq ($(ASCIIDOC),)
    ifneq ($(XMLTO),)
    all: docs
    docs:
       $(MAKE) -C doc/
 
    # Special handling for man pages, they need to be in a dedicated folder
    install: install-man
    install-man:
        $(MKDIR_P) '$(DESTDIR)$(mandir)/man1/'
        $(INSTALL_DATA) $(man_DOCS) '$(DESTDIR)$(mandir)/man1/'
    endif # XMLTO
    endif # ASCIIDOC
 
    # Clean up documentation as well
    clean: clean-docs
    clean-docs:
        $(MAKE) -C doc/ clean

There are three things to note here:

  * Documentation generation is enforced with the rule "docs", forcing kicking build in subfolder doc/
  * Installation of man pages needs to be tricked with an extra rule, here "install-man" to redirect it to the same folder as Postgres man documentation.
  * Documentation cleanup is enforced with a new rule "clean-docs" (could be done better though). Generated documentation is cleaned even if ASCIIDOC or XMLTO is not defined.

Then, here is to how looks doc/Makefile.

    manpages = pg_arman.1
 
    EXTRA_DIST = pg_arman.txt Makefile $(manpages)
 
    htmls = pg_arman.html README.html
 
    # We have asciidoc and xmlto, so build everything and define correct
    # rules for build.
    ifneq ($(ASCIIDOC),)
    ifneq ($(XMLTO),)
    dist_man_MANS = $(manpages)
    doc_DATA = $(htmls)
 
    pg_arman.1: pg_arman.xml $(doc_DATA)
        $(XMLTO) man $<
 
    %.xml: %.txt
        $(ASCIIDOC) -b docbook -d manpage -o $@ $<
 
    %.html: %.txt
        $(ASCIIDOC) -a toc -o $@ $<
 
    README.html: ../README
        $(ASCIIDOC) -a toc -o $@ $<
 
    endif # XMLTO
    endif # ASCIIDOC
 
    clean:
        rm -rf $(manpages) *.html *.xml

What this does is generating of course the man documentation, but as well a set of html pages that can be used for the project website, README included. Of course this is skipped if ASCIIDOC or XMLTO is not defined.

The source of inspiration for that has been actually [pgbouncer](https://github.com/markokr/pgbouncer-dev), the challenge being to simplify enough what was there to have it working with a Postgres extension and PGXS, without any ./configure step and with minimum settings.

As a side note, be sure to set XML\_CATALOG\_FILES correctly on OSX, for example in brew use that:

    export XML_CATALOG_FILES="/usr/local/etc/xml/catalog"

That's something I ran into during my own hacking :)
