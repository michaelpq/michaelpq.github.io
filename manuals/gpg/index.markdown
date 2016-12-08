---
author: Michael Paquier
date: 2011-02-28 13:01:45+00:00
layout: page
type: page
slug: gpg
title: GPG manual
tags:
- git
- manual
- tip
- general
- idea
- GPG
- encryption
- email
- signature
- private
- secret
- public
- key

---

Here is a short manual for GPG.

### Generate a key

The following command can be used:

    gpg --gen-key

Default settings may be enough for your environments, or not. Hence be
careful in what you are using here.

### Add email to key

Here is how to add a new email address to a given key:

    gpg --edit-key
    > adduid
    # Fill in the fields

### Deletion

Here is how to delete a public key associated to an account name, note
that is there are a private key in your private key ring associated with
it it will generate an error.

    gpg --delete-key "User Name"

Here is how to delete a private key from the secret key ring.

    gpg --delete-secret-key "User Name"

### Listing

Here is how to list public keys:

    gpg --list-keys

And here is how to list the private keys:

    gpg --list-secret-keys

### Export

To export a public key:

    gpg --export -a "User Name" > public.key

To export a private key:

    gpg --export-secret-key -a "User Name" > private.key

### Import

To import a public key:

    gpg --import public.key

To import a private key:

    gpg --allow-secret-key-import --import secret.gpg.key

### Encryption and decryption

Here is how to encrypt some data:

    gpg -e -r "User Name" file.txt

And how to decrypt it:

    gpg -d file.txt.gpg
