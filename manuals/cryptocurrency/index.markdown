---
author: Michael Paquier
date: 2014-03-29 12:18:27+00:00
layout: page
type: page
slug: cryptocurrency
title: Cryptocurrency
tags:
- crypto
- currency
- bitcoin
- litecoin
- coin
- peercoin
- mining
- bfgminer
- cgminer
- pool
- build
- solo
- get
- run
- antminer
- command
- overcloacking
---
A cryptocurrency is a digital way to exchange goods and pay for them. There
are many cryptocurrencies:

  * Bitcoin (2009)
  * Peercoin (2011)
  * Litecoin (2011)
  * etc. The number of existing cryptocurrencies has been multiplied since
markets got interest in it and some companies proposed services for them.

Some advices:

  * Keep your wallet yourself and do not use an online service, they
usually request transaction fees to maintain their system, and actually
you do not need them to perform any transactions.
  * Encrypt your wallet(s)
  * Take a backup of your wallet! To be able to recover
  * Use different addresses for transactions you do, it makes harder to
track your wallet and its content.

They have also the following characteristics:

  * Currency model is managed with a protocol and system usually open-sourced
  * Most of them are simply forks of the oldest one, the Bitcoin, they actually
use generally the same client (like Litecoin and Peercoin).
  * Transaction and security model, block mining, validation and number of
coins differ depending on the coin.
  * Two models of algorithms: SHA256 and scrypt. The former is GPU-intensive
for mining. The latter uses both CPU and GPU.
  * Using ressources of a laptop for mining is not recommended and could
result in heat damages on your machines.

If the currency has a low-level of difficulty, you might perhaps be able to
do solo-mining, but it is usually recommended to join a pool and join efforts
with others for a more steady income generated. Two main softwares are
available: bfgminer and cgminer. A preference for the former though as there
are packages for it on many platforms and you don't need to bother about
any custom builds.

In order to join a pool, use a command like this one:

    cgminer -o $STRATUM_TCP_POOL_URL -u $WORKER_NAME -p $WORKER_PASSWORD
    bfgminer -o $STRATUM_TCP_POOL_URL -u $WORKER_NAME -p $WORKER_PASSWORD

Detect the devices available on your system (in this case antminer):

    bfgminer -d? -S antminer:all

Note that when using a device like some USB GPU miner, you might need to
change its chown permissions to the user with which you are running the pool
mining software.

Here is how to do overcloacking for an antminer:

    bfgminer --set-device antminer:clock=$CLOAK_CODE

With the following codes available:

  * x0781 => 1.6GZ
  * x0881 => 1.8GZ
  * x0981 => 2.0GZ
  * x0A81 => 2.2GZ
