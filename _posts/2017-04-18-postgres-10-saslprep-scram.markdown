---
author: Michael Paquier
lastmod: 2017-04-18
date: 2017-04-18 05:18:09+00:00
layout: post
type: post
slug: postgres-10-saslprep-scram
title: 'Postgres 10 highlight - SASLprep in SCRAM-SHA-256'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- 10
- feature
- highlight
- scram
- saslprep
- unicode
- equivalent
- combining

---

An important step in the SCRAM authentication is called SASLprep, a mandatory
feature to be sure about the equivalence of two strings encoded with UTF-8.
[A first commit]( http://git.postgresql.org/pg/commitdiff/818fd4a67d610991757b610755e3065fb99d80a5)
has added support for SCRAM-SHA-256 protocol with the full SASL exchange
plugged on top of it, and this has been implemented by
[the following commit](http://git.postgresql.org/pg/commitdiff/60f11b87a2349985230c08616fa8a34ffde934c8):

    commit: 60f11b87a2349985230c08616fa8a34ffde934c8
    author: Heikki Linnakangas <heikki.linnakangas@iki.fi>
    date: Fri, 7 Apr 2017 14:56:05 +0300
    Use SASLprep to normalize passwords for SCRAM authentication.

    An important step of SASLprep normalization, is to convert the string to
    Unicode normalization form NFKC. Unicode normalization requires a fairly
    large table of character decompositions, which is generated from data
    published by the Unicode consortium. The script to generate the table is
    put in src/common/unicode, as well test code for the normalization.
    A pre-generated version of the tables is included in src/include/common,
    so you don't need the code in src/common/unicode to build PostgreSQL, only
    if you wish to modify the normalization tables.

    The SASLprep implementation depends on the UTF-8 functions from
    src/backend/utils/mb/wchar.c. So to use it, you must also compile and link
    that. That doesn't change anything for the current users of these
    functions, the backend and libpq, as they both already link with wchar.o.
    It would be good to move those functions into a separate file in
    src/commmon, but I'll leave that for another day.

    No documentation changes included, because there is no details on the
    SCRAM mechanism in the docs anyway. An overview on that in the protocol
    specification would probably be good, even though SCRAM is documented in
    detail in RFC5802. I'll write that as a separate patch. An important thing
    to mention there is that we apply SASLprep even on invalid UTF-8 strings,
    to support other encodings.

    Patch by Michael Paquier and me.

    Discussion: https://www.postgresql.org/message-id/CAB7nPqSByyEmAVLtEf1KxTRh=PWNKiWKEKQR=e1yGehz=wbymQ@mail.gmail.com

As referenced in [RFC 4103](https://tools.ietf.org/html/rfc4013), SASLprep is
a successive set of operations working on shaping up a given string for
equivalence comparison:

1. Replace any character in the string by its equivalent mapping. Here there
could be characters mapping for example to nothing.
2. Perform normalization with form KC, which is for example described
[here](http://www.unicode.org/reports/tr15/). This step is itself done
in a couple of sub-steps:
  * Decompose each character using decomposition table, and apply that
    by cascading through each result. This data is part of UnicodeData.txt.
    For Hangul characters mathematical decomposition can be applied, for the
    rest a table is needed.
  * Apply the canonical ordering. An exchange between two adjacent characters
    is done if the combining class of the first character is higher than the
    second, and that the second is not a starter (combining class of 0).
  * Recomposition of the string. Each pair of character is compared and
    reassembled.
3. Prohibit the use of some characters in the output, anything found
returns an error. For example no-space break, U+00A0 is part of that.
4. Check bidi, checking for left-to-right characters, making sure that
the whole string respects bi-directional strings.

There are some libraries around able to do such operations, like GNU's
libidn, and there are as well implementations of SASLprep available in
python, perl or java, but having PostgreSQL have its own implementation
is much more appealing from the licensing point of view. And not having
SASLprep present in the SCRAM implementation may have caused random
breakages when using SCRAM-SHA-256 for a SASL authentication if strings
used in the exchange include non-ASCII characters, making Postgres
non-RFC-compliant with anything else, and that would not be nice.

A dedicated API able to do SASLprep has been added in Postgres, it is
defined in saslprep.c, and caller just needs to use pg\_saslprep() for
this purpose. With this facility in place, it is straight-forward to
get an extension able to do this at SQL wrapper, and here is one,
called [pg\_sasl\_prepare](https://github.com/michaelpq/pg_plugins/tree/master/pg_sasl_prepare).
Note that the sanity checks making sure that the string is encoded in UTF-8
is present in the routine itself.

Normalization form NFKC is also present as a separate routine, called
unicode_normalize_kc() in unicode_norm.c. It could be possible as well
to implement NFC, NFD or NFKC, but even if there are no actual use cases
for them yet, all the infrastructure is here.

This is an important step to make the SCRAM implementation that has been
added in Postgres 10 fully RFC-compliant, and special thanks to Heikki
Linnakangas, who has taken the time to comment, help and at the end commit
the feature, fixing on the way numerous bugs that my first implementations
had.
