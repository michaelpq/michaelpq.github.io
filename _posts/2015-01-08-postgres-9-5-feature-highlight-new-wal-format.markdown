---
author: Michael Paquier
lastmod: 2015-01-08
date: 2015-01-08 06:35:54+00:00
layout: post
type: post
slug: postgres-9-5-feature-highlight-new-wal-format
title: 'Postgres 9.5 feature highlight - New WAL format'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.5
- wal
- replication

---

Today, here is an explanation of one of the largest patches that has hit
PostgreSQL 9.5 illustrated by this commit:

    commit: 2c03216d831160bedd72d45f712601b6f7d03f1c
    author: Heikki Linnakangas <heikki.linnakangas@iki.fi>
    date: Thu, 20 Nov 2014 17:56:26 +0200
    Revamp the WAL record format.

    Each WAL record now carries information about the modified relation and
    block(s) in a standardized format. That makes it easier to write tools that
    need that information, like pg_rewind, prefetching the blocks to speed up
    recovery, etc.

    93 files changed, 3945 insertions(+), 4366 deletions(-)

Each user of PostgreSQL knows [WAL](https://www.postgresql.org/docs/devel/static/wal-intro.html)
as being a sort of internal journal used by the system to ensure data
integrity at recovery with a set a registered REDO actions.

A 7k-patch is a lot for a feature that normal users are not really
impacted by, this new WAL facility finding its interest for developers
who work particularly on tools manipulating WAL as the new set of APIs
available allow to easily track the relation blocks touched by a WAL
record without actually needing to know the WAL record type involved by
exposing the block information at a higher level.

This patch has introduced some additional infrastructure in the files xlog*.c
managing WAL record insertion and decoding, and this is proving to be actually
a net gain in terms of code readability in other portions of the code doing
WAL insertions. For example, here is how a WAL record was roughly inserted in
9.4 and older versions, consisting in having each code paths filling in
sets of XLogRecData (case of the initialization of a sequence relation):

    XLogRecData rdata[2];

    xlrec.node = rel->rd_node;
    rdata[0].data = (char *) &xlrec;
    rdata[0].len = sizeof(xl_seq_rec);
    rdata[0].buffer = InvalidBuffer;
    rdata[0].next = &(rdata[1]);

    rdata[1].data = (char *) tuple->t_data;
    rdata[1].len = tuple->t_len;
    rdata[1].buffer = InvalidBuffer;
    rdata[1].next = NULL;

    recptr = XLogInsert(RM_SEQ_ID, XLOG_SEQ_LOG, rdata);

And here is how it is changed in 9.5:

    XLogBeginInsert();
    XLogRegisterBuffer(0, buf, REGBUF_WILL_INIT);
    XLogRegisterData((char *) &xlrec, sizeof(xl_seq_rec));
    XLogRegisterData((char *) seqtuple.t_data, seqtuple.t_len);
    recptr = XLogInsert(RM_SEQ_ID, XLOG_SEQ_LOG);

The important point in those APIs is XLogRegisterBuffer that can be used
to add information related to a data block in a WAL record. Then the facility
in xlogreader.c/h (already present in 9.4), particularly XLogReadRecord, can
be used by either backend or frontend tools to decode the record information.

Let's see for example how this has affected pg_rewind, which is a facility
able to re-sync a node with another one that has forked with it, particularly
for reusing an old master and reconnect it to a promoted standby. The method
used by this tool is roughly to take a diff of blocks between the two nodes
since the fork point and then to copy the blocks touched back to the target.
In the version based on Postgres 9.4, the block information is extracted
by looking at the resource manager type and then the record type in a way
similar to that:

    void
    extractPageInfo(XLogRecord *record)
    {
        uint8   info = record->xl_info & ~XLR_INFO_MASK;

        /* For each resource manager */
        switch (record->xl_rmid)
        {
            case RM_XLOG_ID:
            [...]
            case RM_HEAP_ID:
            {
                /* For each record type */
                switch (info & XLOG_HEAP_OPMASK)
                {
                    case XLOG_HEAP2_FREEZE_PAGE:
                        /* Get block info */
                        foo();
                    [...]
                }
            }
            [...]
        }
    }

Maintaining such a thing is a pain because each WAL format modification,
something that can happen when a new feature is introduced with the
introduction of new features, or when an existing record format is changed,
is impacted by that. Note that this needs a close monitoring of the commits
happening in upstream PostgreSQL, because each WAL format modification is
not directly mentioned in the release notes (this makes sense as this is
not something users need to bother with). Now let's see how the new WAL
format has affected the block information extraction in pg_rewind, which
is now done with something like that:

    void
    extractPageInfo(XLogRecord *record)
    {
        /* Handle exceptions */
        [...]
        for (block_id = 0; block_id <= record->max_block_id; block_id++)
        {
            RelFileNode rnode;
            ForkNumber forknum;
            BlockNumber blkno;

            if (!XLogRecGetBlockTag(record, block_id, &rnode, &forknum, &blkno))
                continue;
            process();
        }
    }

Note that XLogRecord record now directly contains the number of blocks touched,
the new API XLogRecGetBlockTag allowing to retrieve the relation information
of those blocks. In terms of numbers, the result is a neat reduction of [600 lines]
(https://github.com/vmware/pg_rewind/commit/82ce0be93d81d5b07ff0c4dae687d1a47fede906)
of the code of pg_rewind, as well as many hours saved in maintenance for developer
working on tools doing differential operation based on the analysis of the WAL
content.
