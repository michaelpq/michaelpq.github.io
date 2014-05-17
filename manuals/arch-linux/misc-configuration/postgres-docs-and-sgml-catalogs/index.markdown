---
author: Michael Paquier
date: 2012-08-03 05:28:54+00:00
layout: page
type: page
slug: postgres-docs-and-sgml-catalogs
title: ArchLinux - Postgres docs and sgml catalogs
tags:
- postgres
- jade
- documentation
- sgml
- docbook
- catalog
- install
- linux
- archlinux
- package
- pdf
- html
---

PostgreSQL documentation does not compile natively on ArchLinux.
There are 2 problems explaining why.

  * Those catalog files were not added in jade package for html files.
  * docbook 4.2 are not included correctly in installation, has to be
installed manually.

You might need to install first those packages, some of them being
available only from AUR with [yaourt](/manuals/arch-linux/yaourt/).

    jade
    docbook-dsssl
    docbook
    docbook2x
    docbook-xsl

Necessary files to compile postgresql documentation on ArchLinux are
available here:
	
  * [jade\_catalog\_postgres.tar.gz](/content/pgdocs/jade_catalog_postgres.tar.gz)
  * [docbook-4.2\_postgres.tar.gz](/content/pgdocs/docbook-4.2_postgres.tar.gz)

In order to install those files, you need to do the following things, in
2 steps. jade\_postgres needs to be decompiled and copied in
/usr/share/sgml.

Then docbook needs to be decompressed and installed like this:

    cp docbook.cat docbook.cat.orig &&
    sed -e '/ISO 8879/d' docbook.cat.orig > docbook.cat &&
    cp docbook.cat docbook.cat.orig &&
    sed -e '/gml/d' docbook.cat.orig > docbook.cat &&
    install -d /usr/share/sgml/docbook/sgml-dtd-4.2 &&
    chown -R root:root . &&
    chmod -R 755 . &&
    install docbook.cat /usr/share/sgml/docbook/sgml-dtd-4.2/catalog &&
    cp -af *.dtd *.mod *.dcl /usr/share/sgml/docbook/sgml-dtd-4.2 &&
    install-catalog --add /etc/sgml/sgml-docbook-dtd-4.2.cat \
    /usr/share/sgml/docbook/sgml-dtd-4.2/catalog &&
    install-catalog --add /etc/sgml/sgml-docbook-dtd-4.2.cat \
    /etc/sgml/sgml-docbook.cat

Finally, in order to allow Postgres documentation to compile correctly,
you need to set SGML\_CATALOG\_FILES like this:

    export SGML_CATALOG_FILES=/etc/sgml/catalog:/usr/share/sgml/jade/catalog

### About docbook-dsssl

The package docbook-dsssl is sometimes not available on yaourt due to a
low remote server uptime, download directly its tarball from [here]
(/content/pgdocs/docbook-dsssl-1.79.tar.gz). This is version 1.79. Then
Download the PKGBUILD folder from [here]
(https://aur.archlinux.org/packages/docbook-dsssl) and copy the downloaded
tarball in the root of PKGBUILD folder. Finally launch the following
command to install.

    makepkg -si --skipchecksums

And docbook-dsssl will be installed correctly.
