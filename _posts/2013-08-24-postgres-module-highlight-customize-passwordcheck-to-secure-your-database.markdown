---
author: Michael Paquier
lastmod: 2013-08-24
date: 2013-08-24 06:26:37+00:00
layout: post
type: post
slug: postgres-module-highlight-customize-passwordcheck-to-secure-your-database
title: 'Postgres module highlight - customize passwordcheck to secure your database'
categories:
- PostgreSQL-2
tags:
- break
- case
- character
- database
- hacker
- length
- lower
- number
- password
- policy
- postgres
- postgresql
- protection
- punctuation
- security
- special
- upper
---
[passwordcheck](http://www.postgresql.org/docs/current/static/passwordcheck.html) is a contrib module present in PostgreSQL core using a [hook](/postgresql-2/hooks-in-postgres-super-superuser-restrictions/) present in server code when creating or modifying a role with CREATE/ALTER ROLE/USER able to check a password. This hook is present in src/backend/commands/user.c and called check\_password\_hook if you want to have a look. This module basically checks the password format and returns an error to the user if the password does not satisfy the conditions defined in the module.

By default, this module is able to check two types of passwords:

  * Passwords encrypted with md5. As it is difficult to check an encrypted password, the only check done by default is if the password is equal to the username by doing an encryption of the username and then compare it to the encrypted password.
  * Plain text passwords. It is possible in this case to check on server-side the characters of the password one-by-one and determine if the password satisfies all conditions present in the module. In this case, the password needs to have at least 8 characters and needs to have at least one alphabetical character and one non-alphabetical character.

In order to enable this module, simply add this parameter to postgresql.conf and restart server. This will make the library of passwordcheck being loaded into server when it starts.

    shared_preload_libraries = '$libdir/passwordcheck'

passwordcheck can be easily extended to add checks of passwords using some extra libraries. Have a look at the example with cracklib directly in passwordcheck.c and get inspired by that for your own things! In this case, enabling cracklib is as simple as removing two lines of code and modify Makefile in consequence.

Also, this module is made to be easily extensible and honestly don't apply it to your servers as-is but extend to respect the password policy you need, which is usually more severe than the one present in this module by default. For example, here is a sample of code to check if a plain-text password has at least a lower case, an upper case character and a number. Other characters are not authorized. The former code looks like that:

    /* check if the password contains both letters and non-letters */
    pwd_has_letter = false;
    pwd_has_nonletter = false;
    for (i = 0; i < pwdlen; i++)
    {
        /*
         * isalpha() does not work for multibyte encodings but let's
         * consider non-ASCII characters non-letters
         */
        if (isalpha((unsigned char) password[i]))
            pwd_has_letter = true;
        else
            pwd_has_nonletter = true;
    }
    if (!pwd_has_letter || !pwd_has_nonletter)
        ereport(ERROR,
                (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
                 errmsg("password must contain both letters and nonletters")));

When checking multiple types of characters at the same type for a password, first define some flags for each type:

    #define CONTAINS_LOWER 0x0001 /* Lower-case character */
    #define CONTAINS_UPPER 0x0002 /* Upper-case character */
    #define CONTAINS_NUMBER 0x0004 /* Number */

Then change the core portion with something like that using the flags above:

    int password_flag = 0;
 
    /* Check character validity */
    for (i = 0; i < pwdlen; i++)
    {
        if (isupper((unsigned char) password[i]))
            password_flag |= CONTAINS_UPPER;
        else if (islower((unsigned char) password[i]))
            password_flag |= CONTAINS_LOWER;
        else if (isdigit((unsigned char) password[i]))
            password_flag |= CONTAINS_NUMBER;
        else
            ereport(ERROR,
                    (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
                     errmsg("password contains invalid characters")));
    }

Something also important in this case is to have a code generic enough to return to user all the rules his password breaks in a single error message at the same time such as he knows exactly what doesn't work and can correct his mistakes in one shot. The code for that is pretty straight-forward and it is let as an exercise for the reader. You can still look at the bottom of this article to get a hint of one way to do it.

Once your modified module is ready, upload it to the server and you will get something like this:

    =# create role foo password 'ABCDEFGH';
    ERROR: 22023: Incorrect password format: lower-case character missing, number missing
    LOCATION: check_password, passwordcheck.c:165
    =# create role foo password 'abcdefgh';
    ERROR: 22023: Incorrect password format: upper-case character missing, number missing
    LOCATION: check_password, passwordcheck.c:165
    =# create role foo password '12345678';
    ERROR: 22023: Incorrect password format: lower-case character missing, upper-case character missing
    LOCATION: check_password, passwordcheck.c:165

And you are done! Have fun with this module.

For lazy people, here is a hint for the generic error message: use a stringinfo and wrap your error message with the following if condition.

    if (!(password_flag & CONTAINS_NUMBER) ||
        !(password_flag & CONTAINS_LOWER) ||
        !(password_flag & CONTAINS_UPPER))
