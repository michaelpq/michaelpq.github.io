---
author: Michael Paquier
lastmod: 2015-08-10
date: 2015-08-10 07:35:44+00:00
layout: post
type: post
slug: wal-reader-facility
title: 'WAL reader facility'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- wal
- recovery
- decode
- facility
- log
- xlog
- reader

---

Since PostgreSQL 9.3, the code tree is shipping a file named xlogreader.c
that contains a set of independent routines that can be used to read and
decode WAL records. While it is not available in an independent library,
any frontend or backend application can use it at compilation to be able
to work on WAL. The code of PostgreSQL uses it already in a couple of
places, hence many examples are already available in core to help the
development of plugins with this facility:

  * [pg\_xlogdump](http://www.postgresql.org/docs/devel/static/pgxlogdump.html),
  available since 9.3, is a simple debugging utility aimed at decoding and
  displaying information about WAL.
  * [pg\_rewind](http://www.postgresql.org/docs/devel/static/app-pgrewind.html),
  recently added in PostgreSQL 9.5.
  * [Logical decoding](http://www.postgresql.org/docs/devel/static/logicaldecoding.html),
  introduced in 9.4.

While WAL, being a binary journal aimed at preserving PostgreSQL consistency
in the event of a crash, is hard to apprehend alone, this set of routines
available in xlogreader.c (header xlogreader.h) makes it far easier to understand
and to work on it. Here are the basic things you should know about this facility:

  * An XLOG reader, XLogReaderState, can be allocated with XLogReaderAllocate
  and freed with XLogReaderFree once done with.
  * XLogReadRecord is a key routine, reading a WAL record one at a time and
  allocating a bunch of information in the XLOG reader previously allocated.
  Note that when using it be sure to abuse of InvalidXLogRecPtr as record
  pointer to jump to the next record to read or you may finish in an infinite
  loop easily...
  * The first record position to read can be determined using the file name of
  the WAL segment accessed. Then use XLogFromFileName to determine what is the
  segment number used, and finish with the macro XLogSegNoOffsetToRecPtr to
  get a XLogRecPtr position that can be used for the first lookup using
  XLogReadRecord.

All those pieces of information gathered give the following piece of code
able to perform a basic decoding of WAL:

    XLogRecPtr first_record = InvalidXLogRecPtr; /* can be set by user */
    char *wal_file_name; /* can be set by user */
    XLogRecPtr start_record;
    XLogRecord *record;
    XLogReaderState *xlogreader;
    XLogSegNo segno = 0; /* parsed using file name of WAL segment */
    char *errormsg;

    /* Get segment number if needed */
    XLogFromFileName(fname, &timeline_id, &segno);
    if (XLogRecPtrIsInvalid(first_record))
        XLogSegNoOffsetToRecPtr(segno, 0, first_record);

    /* Create reader */
    xlogreader = XLogReaderAllocate(XLogReadPageBlockCallback, &private);
    /* first find a valid recptr to start from */
    start_record = XLogFindNextRecord(xlogreader, first_record);
    if (start_record == InvalidXLogRecPtr)
    {
        fprintf(stderr, "could not find a valid record after %X/%X",
                        (uint32) (first_record >> 32),
                        (uint32) first_record);
        exit(1);
    }

    /* Now read records in succession */
    do
    {
        record = XLogReadRecord(xlogreader, start_record, &errormsg);

        /* after reading the first record, continue at next one */
        start_record = InvalidXLogRecPtr;

        if (errormsg)
            fprintf(stderr, "error reading xlog record: %s\n", errormsg);

        /*
         * Here perform some stuff using the XLOG reader with
         * decoded WAL record information.
         */
        my_cool_stuff(xlogreader);
    } while (record != NULL);

    XLogReaderFree(xlogreader);

Also, and not mentioned until writing this code, XLogReadPageBlockCallback is
a callback to read a WAL page, ensuring that enough data from the WAL stream
is available when decoding a record, and &private is a private pointer to
store data that can be used by this callback. Examples of such callbacks
are available in xlogdump.c or parsexlog.c.

Now, using this facility and the fact that PostgreSQL 9.5 has changed
WAL format to improve the tracking of modified relation blocks (as
already written [here](/postgresql-2/postgres-9-5-feature-highlight-new-wal-format/)).
I have written a small frontend utility called [pg_wal_blocks]
(https://github.com/michaelpq/pg_plugins/tree/master/pg_wal_blocks) available
in [pg_plugins](https://github.com/michaelpq/pg_plugins) that decodes a series
of WAL records in a segment file and lists to the user the list of blocks
modified by a record and also the relation and database involved. Note that
this is wanted as light-weight, so it is not able to take in input a custom
start position or a range of segments still it shows what can be done with
all the facilities combined.

Hence, after creating a simple table on a fresh cluster...

    =# CREATE TABLE aa AS SELECT generate_series(1,10) AS a;
    SELECT 10
    =# SELECT 'aa'::regclass::oid;
      oid
    -------
     16385
    (1 row)

... Here is what this utility can do:

    $ pg_wal_blocks $PGDATA/pg_xlog/000000010000000000000001 2>&1 | grep "relid = 16385"
    Block touched: dboid = 16384, relid = 16385, block = 0
    Block touched: dboid = 16384, relid = 16385, block = 0
    Block touched: dboid = 16384, relid = 16385, block = 0
    Block touched: dboid = 16384, relid = 16385, block = 0
    Block touched: dboid = 16384, relid = 16385, block = 0
    Block touched: dboid = 16384, relid = 16385, block = 0
    Block touched: dboid = 16384, relid = 16385, block = 0
    Block touched: dboid = 16384, relid = 16385, block = 0
    Block touched: dboid = 16384, relid = 16385, block = 0
    Block touched: dboid = 16384, relid = 16385, block = 0

Yes, there are 10 lines here. Hopefully you find this facility and what it
is possible to do with useful.
