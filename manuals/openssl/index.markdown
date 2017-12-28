---
author: Michael Paquier
date: 2011-02-28 13:01:45+00:00
layout: page
type: page
slug: openssl
title: OpenSSL manual
tags:
- git
- manual
- tip
- general
- idea
- ssl
- encryption
- key
- certificate
- openssl
- csr
- encryption
- client

---

Here is a short manual for OpenSSL.

## Generating Certificates

### Generate RSA Private Key + CSR

    openssl req -out newkey.csr -new -newkey rsa:[bits] -nodes -keyout priv.key

### Generate Self Signed Certificate + Priv Key

    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:[bits] -keyout priv.key -out cert.crt

### Generate CSR for existing Cert

    openssl x509 -x509toreq -in cert.crt -out newreq.csr -signkey priv.key

### Generate CSR for Existing Key

    openssl req -out oldkey.csr -key priv.key -new

### Create a CA

    openssl req -new -x509 -extensions v3_ca -keyout ca.key -out ca.crt -days [days valid]

### Generate Diffie-Hellman Keys

    openssl dhparam -out dhparam.pem [bits]

## Examining Certificates

### Examine a CSR

    openssl req -text -noout -verify -in oldreq.csr

### Examine a Private Key

    openssl rsa -in priv.key -check

### Examine a Certificate

    openssl x509 -in cert.crt -text -noout

### Examine PKCS files

    openssl pkcs12 -info -in key.pfx

## Converting Formats

### PEM to DER

    openssl x509 -outform der -in cert.pem -out cert.der

### DER to PEM

    openssl x509 -inform der -in cert.cer -out cert.pem

### PKCS to PEM

    openssl pkcs12 -in key.pfx -out key.pem -nodes

### PEM to PKCS

    openssl pkcs12 -export -out cert.pfx -inkey priv.key -in cert.crt -certfile ca.crt

## Encryption and Decryption

### List Encryption Schemes

    openssl enc -h

### Advanced Encryption Standard CBC Mode

#### Encrypt

    openssl aes-256-cbc -salt -in priv.txt -out priv.txt.enc

#### Decrypt

    openssl aes-256-cbc -d -in priv.txt.enc -out priv.txt.new

### AES CBC Output as Base64 File

#### Encrypt

    openssl aes-256-cbc -a -salt -in priv.txt -out priv.txt.enc

#### Decrypt

    openssl aes-256-cbc -a -d -in priv.txt.enc -out priv.txt.new

## Check Remote Certificates

### HTTPS Server

    openssl s_client -showcerts -connect www.example.com:443

### IMAP Server

    openssl s_client -showcerts -starttls imap -connect mail.eample.com:139

### XMPP Server

    openssl s_client -showcerts -starttls xmpp -connect chat.example.com:5222

### Present Client Certificate

    openssl s_client -showcerts -cert cert.crt -key cert.key -connect www.example.com:443

## Verify Certificates

### Verify Certificate with CA Certificate

    openssl verify -verbose -CAFile ca.crt cert.crt

### Verify Private Key Matches Certificate

    openssl x509 -modulus -noout -in cert.crt | openssl md5
    openssl rsa -modulus -noout -in priv.key | openssl md5
