---
author: Michael Paquier
lastmod: 2015-10-24
date: 2015-10-24 11:44:23+00:00
layout: post
type: post
slug: pgctl-start-improvements
title: 'Reliability improvements for pg_ctl start'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- open source
- database
- development
- postmaster
- pid
- pg_ctl
- start
- reliability
- improvement
- repeatable
- seconds

---

Just after the last set of minor versions of Postgres has been released,
the following commit has popped up on all the stable branches to improve
a long-time weird behavior of pg\_ctl start.

    commit: 6bcce25801c3fcb219e0d92198889ec88c74e2ff
    author: Tom Lane
    date: Mon, 12 Oct 2015 18:30:36 -0400
    Fix "pg_ctl start -w" to test child process status directly.

    pg_ctl start with -w previously relied on a heuristic that the postmaster
    would surely always manage to create postmaster.pid within five seconds.
    Unfortunately, that fails much more often than we would like on some of the
    slower, more heavily loaded buildfarm members.

    [...]

    Back-patch to all supported versions, both because the current behavior
    is buggy and because we must do that if we want the buildfarm failures
    to go away.

    Tom Lane and Michael Paquier

Before this commit pg\_ctl used the assumption that a postmaster would create
its PID file within 5 seconds after starting, hence running successively this
command produced rather inconsistent exit codes. Take for example this sequence
of commands:

    $ pg_ctl -w start && echo "## 1st command run" && \
        pg_ctl -w start && echo "## 2nd command run" && \
        sleep 5 && \
        pg_ctl -w start && echo "## 3rd command run"
    done
    server started
    ## 1st command run
    done
    server started
    ## 2nd command run
    pg_ctl: another server might be running; trying to start server anyway
    waiting for server to start....
    pg_ctl: this data directory appears to be running a pre-existing postmaster
    stopped waiting
    pg_ctl: could not start server
    Examine the log output.

When using pg\_ctl in wait mode (with -w), the first and second commands
actually succeed, and that is only after a couple of seconds that pg\_ctl
reports an actual failure, symbolized by postmaster.pid being detected. Now,
with the previous patch applied, things get more consistent. When running two
times in a row "pg\_ctl start" the second one will properly fail:

    $ pg_ctl -w start && echo "## 1st command run" && \
      pg_ctl -w start && echo "## 2nd command run"
	  done
    server started
    ## 1st command run
    pg_ctl: another server might be running; trying to start server anyway
    waiting for server to start....
    stopped waiting
    pg_ctl: could not start server
    Examine the log output.

The old logic based on system() is replaced by a combination of fork()
and exec() which has the advantage to allow fetching the PID of the
postmaster, that pg\_ctl can reliably wait for using waitpid(). One
limitation is on Windows, where what is waited for is not the postmaster
PID but the PID of the shell process that launched the postmaster, so
there is a need to wait for two or three seconds to have a reliable
result. Still the new behavior is better than the old one that caused
random failures in a handful of slow buildfarm machines, like Raspberry
PIs.

This will be available in the next set of minor versions, aka 9.4.6, 9.3.11,
9.2.14 and 9.1.20. Production environments usually do not rely on that,
still that's something to be careful about, now things get right.
