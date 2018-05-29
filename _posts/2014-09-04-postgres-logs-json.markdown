---
author: Michael Paquier
lastmod: 2014-09-04
date: 2014-09-04 03:07:33+00:00
layout: post
type: post
slug: postgres-logs-json.markdown
title: 'Postgres logs in JSON format'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- log
- json

---

Customizing the shape of logs written by a PostgreSQL server is possible
using a [hook](https://wiki.postgresql.org/images/e/e3/Hooks_in_postgresql.pdf)
present in core code invocated before sending anything to the server logs.

This hook is present in elog.c and is defined as follows:

    emit_log_hook_type emit_log_hook = NULL;
	[...]
    if (edata->output_to_server && emit_log_hook)
        (*emit_log_hook) (edata);

Note that it uses ErrorData as argument, structure defined in elog.h
containing a lot of status information about the log entry generated.

In order to activate the hook, it is necessary to register a custom routine
defined in a library loaded by core server at postmaster startup via
shared\_preload\_libraries. The module presented in this post, named
jsonlog and able to reshape log messages as JSON objects (1 object per
log entry), uses the following basic infrastructure to use the logging
hook correctly:

    PG_MODULE_MAGIC;

    void _PG_init(void);
    void _PG_fini(void);

    /* Hold previous logging hook */
    static emit_log_hook_type prev_log_hook = NULL;

    void
    _PG_init(void)
    {
        prev_log_hook = emit_log_hook;
        emit_log_hook = write_jsonlog;
	} 

    void
    _PG_fini(void)
    {
        emit_log_hook = prev_log_hook;
	}

Then it is a matter of defining the custom routine write\_jsonlog able
to rewrite the log entry sent to server using for example a StringInfo
structure appending new JSON fields. This code has nothing really
complicated and readers are invited to have a look [here]
(https://github.com/michaelpq/pg_plugins/blob/master/jsonlog/jsonlog.c)
for all the details. Basically what it does is initializing and finalizing
correctly the JSON string, filling it with JSON fields depending on the
error status fields available when the custom routine is called. Once
object is built it is written out. Note that the extension is made to
block other logging on server by updating output\_to\_server to false
in ErrorData and that the strings generated as field values are made
as legal JSON by using the in-core function escape\_json. The same
field as CSV output are as well covered in the string generation. Then,
expect an increase of log volume as the field names need to be set all
the time with their respective values.

Finally, loading this module can be done by adding this parameter in
postgresql.conf:

    shared_preload_libraries = 'jsonlog'

Once server starts, logs will become only JSON, like that (understand
of course that this is on two lines only to accomodate with this
article format):

    {"timestamp":"2014-09-04 11:31:04.673T","pid":60379,"session_id":"5407cee8.ebdb",
     "error_severity":"DEBUG","message":"checkpoint record is at 0/16C99B8"} 

The field names may not be the best ones ever, but any suggestion is
welcome. The code of this module has been added in [pg_plugins]
(https://github.com/michaelpq/pg_plugins) as [jsonlog]
(https://github.com/michaelpq/pg_plugins/tree/master/jsonlog).

Note that this module is compatible down to Postgres 9.2, where the hook
to control logging output has been introduced. Filtering options may be
worth doing as well, so patches are welcome.
