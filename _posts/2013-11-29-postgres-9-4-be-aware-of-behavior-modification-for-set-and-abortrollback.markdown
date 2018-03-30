---
author: Michael Paquier
lastmod: 2013-11-29
date: 2013-11-29 03:24:29+00:00
layout: post
type: post
slug: postgres-9-4-be-aware-of-behavior-modification-for-set-and-abortrollback
title: 'Postgres 9.4: Be aware of behavior modification for SET and ABORT/ROLLBACK'
categories:
- PostgreSQL-2
tags:
- 9.4
- postgres
- postgresql
- transaction
- rollback

---
Here is something to be aware of if you have a couple of scripts relying on this behavior: ROLLBACK, ABORT and SET behavior have been changed in PostgreSQL 9.4. The modification has been introduced by this commit:

    commit a6542a4b6870a019cd952d055d2e7af2da2fe102
    Author: Bruce Momjian
    Date: Mon Nov 25 19:19:40 2013 -0500

    Change SET LOCAL/CONSTRAINTS/TRANSACTION and ABORT behavior
 
    Change SET LOCAL/CONSTRAINTS/TRANSACTION behavior outside of a
    transaction block from error (post-9.3) to warning. (Was nothing in <=
    9.3.) Also change ABORT outside of a transaction block from notice to
    warning.

    There is nothing really complicated in that but let's have a look...

From 9.4, ROLLBACK and ABORT return WARNING messages when launched outside a transaction block, while SET . The commit message is enough explicit about that though...

    =# ROLLBACK;
    WARNING: 25P01: there is no transaction in progress
    LOCATION: UserAbortTransactionBlock, xact.c:3458
    ROLLBACK
    =# ABORT;
    WARNING: 25P01: there is no transaction in progress
    LOCATION: UserAbortTransactionBlock, xact.c:3458
    ROLLBACK
    =# SET LOCAL search_path = 'public';
    WARNING: 25P01: SET LOCAL can only be used in transaction blocks
    LOCATION: CheckTransactionChain, xact.c:3015
    SET

Note the consistency with COMMIT:

    =# COMMIT;
    WARNING: 25P01: there is no transaction in progress
    LOCATION: EndTransactionBlock, xact.c:3365
    COMMIT

And with BEGIN inside a transaction block:

    =# BEGIN;
    BEGIN
    =# BEGIN;
    WARNING: 25001: there is already a transaction in progress
    LOCATION: BeginTransactionBlock, xact.c:3174
    BEGIN

In 9.3 those behaviors are far more inconsistent. SET LOCAL returns nothing (!?) (ERROR for <= 9.2), ROLLBACK and ABORT a NOTICE message, and COMMIT a WARNING.

    =# ROLLBACK;
    NOTICE: 25P01: there is no transaction in progress
    LOCATION: UserAbortTransactionBlock, xact.c:3435
    ROLLBACK
    =# ABORT;
    NOTICE: 25P01: there is no transaction in progress
    LOCATION: UserAbortTransactionBlock, xact.c:3435
    ROLLBACK
    =# SET LOCAL search_path = 'public';
    SET

It is hard to have an opinion about such choices, however the new way of doing for 9.4 is consistent among all the transaction commands, clearly facilitating writing scripts that rely on such checks (be ready to refactor them).

Finally, don't forget that those messages can be silenced by using client\_min\_messages by setting it to a level higher than WARNING if you don't to be annoyed, this setting being particularly interesting for ABORT.

    =# SET client_min_messages TO ERROR;
    SET
