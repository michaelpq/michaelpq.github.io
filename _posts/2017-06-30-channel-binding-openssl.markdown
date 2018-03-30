---
author: Michael Paquier
lastmod: 2017-06-30
date: 2017-06-30 02:18:44+00:00
layout: post
type: post
slug: channel-binding-openssl
title: 'Channel binding with OpenSSL and Postgres'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- ssl
- scram
- security

---

With the SCRAM implementation done in Postgres 10, it is time to move
on with other things in this area. The next, and perhaps last, area of
focus in the implementation of channel binding, on which a patch has
been [submitted](https://www.postgresql.org/message-id/CAB7nPqTZxVG9Lk0Ojg7wUR4mhGGd_W=Qa4+7wuhy6k75kE9keg@mail.gmail.com)
for integration into Postgres 11.

Channel binding is a concept defined in
[RFC 5056](https://tools.ietf.org/html/rfc5056), to ensure that the frontend
and the backend connecting to each other are the same in order to prevent
man-in-the-middle attacks.

[RFC 5802](https://tools.ietf.org/html/rfc5802), which is the specification
for SCRAM, has a section dedicated to channel binding. In the context of
Postgres, if a client attempts an SSL connection, then the server needs to
advertise the SASL mechanism named SCRAM-SHA-256-PLUS, on top of the existing
SCRAM-SHA-256 that has been implemented in Postgres 10, to let the client
choose if it wants to perform channel binding or not. For Postgres, with an
SSL connection, and if the server has published the -PLUS mechanism, a client
has to choose the channel binding option or the server would consider that
as a downgrade attack if choosing the non-PLUS channel. The protocol used
for the exchange is defined in the
[documentation](https://www.postgresql.org/docs/devel/static/sasl-authentication.html).

As mentioned by [RFC 5929](https://tools.ietf.org/html/rfc5929), there are
several types of channel bindings, which define the channel binding data
their own way:

  * tls-unique, which uses the TLS finish message bytes.
  * tls-server-end-point, which uses a hash of the server certificate.
  * tls-unique-for-telnet, which uses the TLS finish messages sent by the
  server and the client after the handshake.

Both of them need to be encoded with base-64. Note that per the definition
available, a SCRAM implementation has to implement tls-unique, the other two
ones being optional.

The patch proposed to the community at the time this post is written
implements two of them: tls-unique and tls-server-end-point. The former
because of its mandatory nature, and the second one after discussion to
ease the integration of channel binding in the Postgres JDBC driver, where
getting the TLS finish message data can be a dependency pain.

Now, finding out how to implement both things has required quite a bit of
lookup at the OpenSSL code which shines per its lack of documentation on
a couple of aspects. Hopefully what follows will help people to find out
how to implement their own channel binding.

First for tls-unique, OpenSSL provides two routines to fetch the TLS finish
message, which are undocumented:

  * SSL_get_finished(), to get the bytes of the TLS finish message sent by
  the client.
  * SSL_get_peer_finished(), to get the TLS finish message received by the
  peer.

In short, implementing tls-unique is a matter of the following things with
OpenSSL:

  * After the SSL handshake is done, call SSL_get_finished() on the client,
  encode it in base64, and then append it to the message sent to the server
  during the SASL exchange.
  * On the server, use SSL_get_peer_finished(), encode it in base64, and then
  compare it to the data received from the client.

Be careful that you should use the full TLS finish message as channel binding
data.

Then comes tls-server-end-point, which needs more routines from OpenSSL,
first to get the server certificate and hash it:

  * SSL_get_peer_certificate() to get the peer certificate data, which needs
  to be used on the client side in this case.
  * SSL_get_certificate() to get the local certificate data, and this is
  called on the server.

Once this information is fetched, hashing it it first necessary. In this
process comes a detail of RFC 5929: if the signature algorithm of a
certificate is MD5 or SHA-1, then the hashing needs to be done with SHA-256.
For anything above, use the same hashing. Getting a hash from a certificate
is a matter of using X509_digest(), but the algorithm type to specify
depends on the signature algorithm the certificate is using. Digging
through the code of OpenSSL, I have found an answer of how to do that
in crypto/asn1/a_verify.c:

  * Use X509_get_signature_nid() to find the signature algorithm, note
  that this may not be the hash itself.
  * Then apply OBJ_find_sigid_algs() to find out the real algorithm.

Here is a snippet of code from the submitted patch to explain that
point better than words:

    const EVP_MD   *algo_type = NULL;
    char            hash[EVP_MAX_MD_SIZE];  /* size for SHA-512 */
    unsigned int    hash_size;
    int             algo_nid;
    X509          *server_cert;

    /* Get certificate data, be careful that this could be NULL */
    server_cert = SSL_get_certificate(port->ssl);

    /*
     * Get the signature algorithm of the certificate to determine the
     * hash algorithm to use for the result.
     */
    if (!OBJ_find_sigid_algs(X509_get_signature_nid(server_cert),
                             &algo_nid, NULL))
        elog(ERROR, "could not find signature algorithm");

    /* Switch to the hashing algorithm to use */
    switch (algo_nid)
    {
        case NID_sha512:
            algo_type = EVP_sha512();
            break;

        case NID_sha384:
            algo_type = EVP_sha384();
            break;

        /*
         * Fallback to SHA-256 for weaker hashes, and keep them listed
         * here for reference.
         */
        case NID_md5:
        case NID_sha1:
        case NID_sha224:
        case NID_sha256:
        default:
            algo_type = EVP_sha256();
            break;
    }

    /* generate and save the certificate hash */
    if (!X509_digest(server_cert, algo_type, (unsigned char *) hash,
                     &hash_size))
        elog(ERROR, "could not generate server certificate hash");

    /* the result is *hash, you may want to copy it */
    ...

With the result at hand, it is finally just a matter of encoding it in
base-64 and appending the result string into the SASL exchange message.
