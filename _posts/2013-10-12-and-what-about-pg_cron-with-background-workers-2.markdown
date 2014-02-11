---
author: Michael Paquier
comments: true
date: 2013-10-12 06:19:32+00:00
layout: post
slug: and-what-about-pg_cron-with-background-workers-2
title: 'And what about pg_cron with background workers?'
wordpress_id: 2006
categories:
- PostgreSQL-2
tags:
- 9.3
- 9.4
- cron
- crontab
- database
- file
- frequency
- job
- launcher
- maintenance
- master
- open source
- periodic
- pg_cron
- postgres
- query
- slave
- sql
- start
- worker
---
With the introduction of background workers in Postgres 9.3 and even the introduction of dynamic background workers, allowing to start workers while server is running, there is quite a bit of infrastructure in place to play with.

Even if the final target of the work being done in 9.4 development is the introduction of some sort of parallel query sort, the current infrastructure already committed permits to implement plug-ins that have a master/slave worker infrastructure where a master process decides when to spawn slave processes and what they do, like deciding to the database to connect to. This is way similar to what the autovacuum launcher does with its workers.

Background workers are expected to run as daemons and run periodically actions on either the platform where process is running or interact with the Postgres server itself. In the latter case what is usually expected is the possibility to run actions on the server that would do either maintenance or more specific things like gathering statistics. In all those cases the actions done on server share those points:

  * Automatic schema initialization might be needed before performing any periodic actions on server
  * Not only one query, but a set of queries is usually run
  * Parametrize queries performing actions (?)

In short (and this is the topic of this post), people are looking for a generic solution that they could use to solve those problems in a generic way without having to recode all the time the same for loop preforming an hard-coded query that might take as parameters a custom GUC parameter as you could for example see in some of the background worker examples I got on github. So, this finally orientates this post to its real subject which is the implementation of such a generic module that could be called pg_cron, or simply the way to run cron jobs with a Postgres server. The rest of this post proposes a design about how to achieve that, all the ideas you might have after reading this post are welcome! Let's call that a participative community design. Posting that on the community mailing lists looks a bit too early yet, as it is not related to Postgres core at all... So why not a blog post?  

### Overall design ###

Here is a list of the main things coming to my mind about pg_cron (might be updated later depending on comments and second thoughts, but will keep a track of what has been edited at the bottom of the post):

  * It runs with a master/slave process structure in a way similar to autovacuum with a launcher and workers.
  * Decision of which database a worker process connects to is made by the launcher process, and passes the database name when spawning the worker process.
  * Workers can only perform one single action, and stop once the action is complete.
  * The list of SQL commands as well as the parameters it uses (if any) are passed from the launcher to the worker.
  * Launcher will need to monitor the worker processes it activated periodically. At the date when this post is written, background worker API offers the possibility to fetch back the PID of a process spawned dynamically.
  * Launcher process tracks automatically changes in the scheduler, so no user intervention is needed. This is useful when combined with a nap time for launcher. Another way around is to have the launcher calculate when the next time to kick a worker is, and sleep until that moment. This would however need to be combined with user intervention when he updates the scheduler. Both methods have pros and cons.

Also, if someone comes up with a clear example about how to use parametrized queries in this context, feel free to post a comment. If this is not really needed, the first versions of pg_cron might not include any kind of support for that, but design needs to take into account such possible extensions.  

### Scheduler ###

There are two approaches possible here:

  * Use of an external configuration file
  * Use an internal database schema initialized and used by launcher process.

In the first case, the configuration file could have the following shape, similar to a crontab:

    * * * * * * $DBNAME $QUERIES/$FILE_OF_QUERY

In the second case, it could be a simple table tracking the following things:

  * Name of the task
  * Interval of time when task is kicked
  * Last time it got kicked
  * PID of the task launched if it is running, 0/NULL if nothing.

As monitoring could be achieved by launcher using pg_stat_activity, the second approach looks better. The database where this schema is stored could be defined with a custom GUC parameter, that cannot be changed once server has started. Schema could be reinitialized if the database name changes after restart for example. Also, the frequency at which worker activity is controlled could be controlled with an additional parameter, reloadable, being a nap time. Any additional ideas here are welcome.
