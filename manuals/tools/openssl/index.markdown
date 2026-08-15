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

## Detect openssl version

openssl version can be found by using SSLeay_version in libcrypto.so, and
this function can be found for example directly by using dlsym in the
library libcrypto.so or even dylib. Here is a simple example of code able to
do so.

    #include <stdio.h>
    #include <dlfcn.h>

    typedef const char *(*SSLEAY_VERSION)(int t);

    int main(int argc, char* argv[])
    {
        void *lib;
        SSLEAY_VERSION SSLeay_version;

        /* Sanity check */
        if (argc != 2)
        {
            printf("USAGE: %s /path/to/libcrypto.so\n", argv[0]);
            return 1;
        }

        /* Try to open library given by user */
        lib = dlopen(argv[1], RTLD_NOW);
        if (lib == NULL)
        {
            printf("%s\n", dlerror());
            return 1;
        }

        /* Grab the object wanted, here openssl version function */
        SSLeay_version = (SSLEAY_VERSION) dlsym(lib, "SSLeay_version");
        if (SSLeay_version == NULL)
        {
            printf("%s\n", dlerror());
            dlclose(lib);
            return 1;
        }
        printf("SSL version %s\n", SSLeay_version(0));

        /* Clean up */
        dlclose(lib);
        return 0;
    }

Compile this code for example like that and then it is simple to use:

    $ gcc -g -o openssl_version openssl_version.c -ldl
    $ openssl_version /path/to/libcrypto.[so|dylib]
    SSL version OpenSSL 1.0.1h-fips 5 Jun 2014

Actually this trick with dlsym can be used on any functions for any library,
just be sure that library dependencies are covered when compiling the code.
