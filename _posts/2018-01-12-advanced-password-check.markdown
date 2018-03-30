---
author: Michael Paquier
lastmod: 2018-01-12
date: 2018-01-12 07:44:44+00:00
layout: post
type: post
slug: advanced-password-check
title: 'Advanced Password Checks'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- pg_plugins
- passwordcheck

---

[passwordcheck](https://www.postgresql.org/docs/devel/static/passwordcheck.html)
is a PostgreSQL contrib module able to check if raw password strings are
able to respect some policies. For encrypted password, which is what should
be used in most cases to avoid passing plain text passwords over the wire
have limited checks, still it is possible to check for example for MD5-hashed
entries if they match the user name. For plain text password, things get
a bit more advanced, with the following characteristics:

  * Minimum length of 8 characters.
  * Check if password has the user name.
  * Check if password includes both letters and non-letters.
  * Optionally use cracklib for more checks.

Note that all those characteristics are decided at compilation time and that
it is not possible to configure it, except by forking the code and creating
your own module. [passwordcheck_extra](https://github.com/michaelpq/pg_plugins/tree/master/passwordcheck_extra)
is a small module that I have written to make things more flexible with a
set of configuration parameters aimed at simplifying administration:

  * Minimum length of password.
  * Maximum length of password.
  * Define a custom list of special characters.
  * Decide if password should include at least one special character,
  one lower-case character, one number or one upper-case character (any
  combination is possible as there is one switch per type).

In order to enable this module, you should update shared\_preload\_libraries
and list it:

    shared_preload_libraries = 'passwordcheck_extra'

And then this allows for more fancy checks than the native module, for
example here to enforce only numbers to be present, with a length enforced
between 4 and 6 (don't do that at home):

    =# LOAD 'passwordcheck_extra';
    LOAD
    =# SET passwordcheck_extra.restrict_lower = false;
    SET
    =# SET passwordcheck_extra.restrict_upper = false;
    SET
    =# SET passwordcheck_extra.restrict_special = false;
    SET
    =# SET passwordcheck_extra.minimum_length = 4;
    SET
    =# SET passwordcheck_extra.maximum_length = 6;
    SET
    =# CREATE ROLE hoge PASSWORD 'foobar';
    ERROR:  22023: Incorrect password format: number missing
    =# CREATE ROLE hoge PASSWORD 'fooba1';
    CREATE ROLE

One property to note is that all error messages concatenate, so for example
if all the previous parameters are switched to true, you get more advanced
knowledge of what is missing (error message format is split into multiple
lines for the reader's sake):

    =# CREATE ROLE hoge PASSWORD '1234';
    ERROR:  22023: Incorrect password format:
        lower-case character missing,
        upper-case character missing,
        special character missing (needs to be one listed in "!@#$%^&*()_+{}|<>?=")

More fancy things could be done, like using counters to decide at least
a number of character for each type to be present. Have fun.
