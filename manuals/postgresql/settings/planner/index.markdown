---
author: Michael Paquier
date: 2012-08-03 12:04:52+00:00
layout: page
type: page
slug: planner
title: PostgreSQL - Planner
tags:
- postgres
- postgresql
- planner
- settings
- tuning
- performance
- index
- cost
- path
---
Here are a couple of tips for planner settings.
	
  * **effective\_io\_concurrency**, set to the number of I/O channels or ignore it	
  * **random\_page\_cost**
   * 3.0 for a typical RAID10 array
   * 2.0 for a SAN
   * 1.1 for Amazon EBS
