---
author: Michael Paquier
lastmod: 2012-04-03
date: 2012-04-03 08:42:08+00:00
layout: post
type: post
slug: split-an-image-file-into-tiles
title: Split an image file into tiles
categories:
- Linux-2
tags:
- convert
- crop
- image
- imagemagick
- linux
- manipulation
- split
- ubuntu
---

With ImageMagick package (image manipulation library) installed on a Linux machine, it is possible to split a huge image file into smaller tiles with such kind of command:

    convert -crop $WIDTHx$HEIGHT@ huge_file.png  tile_%d.png

With the following parameters.

  * $WIDTH, the width of each tile splitted
  * $HEIGHT, the height of each tile splitted

Here is an example to split a file into tiles of size 16x32 pixels:

    convert -crop 16x32@ huge_file.png  tile_%d.png

