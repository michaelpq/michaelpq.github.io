---
author: Michael Paquier
date: 2015-08-20 14:14:18+00:00
layout: page
type: page
slug: perf
title: PostgreSQL - Kerkeros and GSSAPI
tags:
- postgres
- postgresql
- kerberos
- security
- linux
- krb5
- gss
- gssapi
- pg_hba
- setup
- development

---

Here are some instructions to set up on a local machine a Kerberos KDC (Key
Distributor Center) with a set of keys usable on a Postgres server to connect
to it using GSSAPI.

## Server-side setup

The Kerberos server realm will be set with a fake domain called
myrealm.example and this name is used in all the settings present on this
page. This portion needs to be done as user root.

First, add an entry in /etc/hosts with the IP address of your machine, this
will be used as the lookup entry by the Kerberos server:

    echo 192.168.172.128 myrealm.example >> /etc/hosts

Now here is a configuration file for the Kerberos server, set up with the
realm cited above, configuration is saved as /etc/krb5.conf:

    [logging]
        default = FILE:/var/log/krb5libs.log
        kdc = FILE:/var/log/krb5kdc.log
        admin_server = FILE:/var/log/kadmind.log

    [libdefaults]
        default_realm = MYREALM.EXAMPLE
        dns_lookup_realm = false
        dns_lookup_kdc = false
        ticket_lifetime = 24h
        renew_lifetime = 7d
        forwardable = yes
        default_tgs_enctypes = aes128-cts des3-hmac-sha1 des-cbc-crc des-cbc-md5
        default_tkt_enctypes = aes128-cts des3-hmac-sha1 des-cbc-crc des-cbc-md5
        permitted_enctypes = aes128-cts des3-hmac-sha1 des-cbc-crc des-cbc-md5

    [realms]
        MYREALM.EXAMPLE = {
            kdc = myrealm.example:88
            admin_server = myrealm.example:749
            default_domain = myrealm.example
        }

    [domain_realm]
        .myrealm.example = MYREALM.EXAMPLE
        myrealm.example = MYREALM.EXAMPLE

    [appdefaults]
        pam = {
            debug = false
            ticket_lifetime = 36000
            renew_lifetime = 36000
            forwardable = true
            krb4_convert = false
        }

Now create the KDC database for the realm setup with the following command
(if the database does not create, you may have to create by yourself
/var/lib/krb5kdc which is the default path of the database for ArchLinux,
and note as well that a password is expected here):

    kdb5_util create -s

The Kerberos utility uses kadmin to authenticate to the server, it is
always better to add an administrator to the KDC database:

    kadmin.local -q "addprinc postgres/admin"

Now that everything is running, run this command that will create the KDC
daemon that the client can query at will (use a service startup script if
you want, perhaps it does not matter much for development though):

    krb5kdc

## Database role in KDC database

This portion needs to be done as user root.

Using *kadmin.local*, type the following command to add the database role
to the KDC database (note that a password is expected here):

    addprinc postgres/myrealm.example@MYREALM.EXAMPLE

Note three things here:

  * The part "postgres/" is expected by the PostgreSQL server when
  connecting.
  * The second part "myrealm.example" needs to be the IP mapping to
  the KDC server.
  * The third part is the name of the realm as set in the Kerberos
  configuration on server side.

Now create a keytab file that will be needed by the PostgreSQL server
for the user that has just been created, this needs to be kicked with
*kadmin.local*:

    xst -k myrealm.example.keytab postgres/myrealm.example@MYREALM.EXAMPLE

This creates a set of entries for this database user that will be
used as validation for the PostgreSQL backend.

## Set up the Kerberos client

This portion can be done as user non-root, but first copy the keytap
file that has just been created and give access to it to the client
with chown.

Remove any existing entries with this command:

    kdestroy

And now use *kinit* to request a ticket to the KDC server. Note that you
need the keytab file previously created.

    kinit -k -t myrealm.example.keytab  postgres/myrealm.example@MYREALM.EXAMPLE

Then use klist to display the contents of the ticket, things should show
up as follows, more or less:

    $ klist
    Ticket cache: FILE:/tmp/krb5cc_1000
    Default principal: postgres/myrealm.example@MYREALM.EXAMPLE
    Valid starting     Expires            Service principal
    08/21/15 18:10:08  08/22/15 18:10:08  krbtgt/MYREALM.EXAMPLE@MYREALM.EXAMPLE

## Setup the database for GSSAPI connection

First create the user on the database side that will be used for the
operations:

    psql -c 'CREATE ROLE "postgres/myrealm.example@MYREALM.EXAMPLE.COM" SUPERUSER LOGIN'

Update postgresql.conf to point to the keytab file previously created:

    krb_server_keyfile = '/home/postgres/myrealm.example.keytab

And add this entry in pg_hba.conf:

    host all all 0.0.0.0/0 gss include_realm=0 krb_realm=MYREALM.EXAMPLE

Don't forget to reload parameters on the servers, and now you should
be able to connect using GSSAPI:

    psql -U "postgres/myrealm.example@MYREALM.EXAMPLE" -h myrealm.example postgres

There are far more fancy things doable like using pg_ident to map user
names for more convenient deployments but this is enough for development
purposes.
