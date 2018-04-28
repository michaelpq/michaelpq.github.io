---
author: Michael Paquier
lastmod: 2018-04-28
date: 2018-04-28 08:50:33+00:00
layout: post
type: post
slug: postgres-11-group-access
title: 'Postgres 11 highlight - Group access on data folder'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 11
- administration
- backup
- cluster

---

The following commit, which has introduced a new feature for PostgreSQL 11,
introduces the possibility to lower a bit the set of permissions around
data folders:

    commit: c37b3d08ca6873f9d4eaf24c72a90a550970cbb8
    author: Stephen Frost <sfrost@snowman.net>
    date: Sat, 7 Apr 2018 17:45:39 -0400
    Allow group access on PGDATA

    Allow the cluster to be optionally init'd with read access for the group.

    This means a relatively non-privileged user can perform a backup of the
    cluster without requiring write privileges, which enhances security.

    The mode of PGDATA is used to determine whether group permissions are
    enabled for directory and file creates.  This method was chosen as it's
    simple and works well for the various utilities that write into PGDATA.

    Changing the mode of PGDATA manually will not automatically change the
    mode of all the files contained therein.  If the user would like to
    enable group access on an existing cluster then changing the mode of all
    the existing files will be required.  Note that pg_upgrade will
    automatically change the mode of all migrated files if the new cluster
    is init'd with the -g option.

    Tests are included for the backend and all the utilities which operate
    on the PG data directory to ensure that the correct mode is set based on
    the data directory permissions.

    Author: David Steele <david@pgmasters.net>
    Reviewed-By: Michael Paquier, with discussion amongst many others.
    Discussion: https://postgr.es/m/ad346fe6-b23e-59f1-ecb7-0e08390ad629%40pgmasters.net

Group access on the data folder means that files can optionally use 0640 as
mask and folders can use 0750, which becomes handy for particularly backup
scenarios where a different user than the one running PostgreSQL would be
sufficient to take a backup of the instance.  For some security policies,
it is important to do an operation with a user which has the minimum set
of permissions allowing to perform the task, so in this case a user which
is member of the same group as the one running the PostgreSQL instance would
be able to read all files in a data folder and take a backup from it.  So
not only this is useful for people implementing their own backup tool, but
also for administrators looking at users able to do the backup task with only
a minimal set of access permissions.

The feature can be enabled using initdb -g/--allow-group-access, which will
create files using 0640 as mask and folder using 0750.  Note that in
v10 and older versions, trying to start a server with the base data
folder having a permission different than 0700 results in a failure of
the postmaster process, so with v11 and above the postmaster is able to
start if the data folder is found as using either 0700 or 0750.  Note
that an administrator can also perfectly initialize a data folder without
the option --allow-group-access first, and change it to use group
permissions after with chmod -R or such, and the cluster will adapt
automatically.  In order to know if a data folder uses group access,
a new GUC parameter called data\_directory\_mode is available, which
returns the mask used, so for a data folder allowing group access
you would see that:

    =# SHOW data_directory_mode;
     data_directory_mode
    ---------------------
     0750
    (1 row)

Sometimes deployments of PostgreSQL use advanced backup strategies
mixing multiple solutions, which is why the following in-core tools
also respect if group access is allowed in a cluster when fetching
and writing files related to the cluster:

  * pg\_basebackup, which respects permissions for both the tar and plain
  formats.
  * pg\_receivewal will create new WAL segments using group permissions.
  * pg\_recvlogical does the same for logical changes received.
  * pg\_rewind.
  * pg\_resetwal.

Note that it is not possible to enforce the mask received, so if a
cluster has group access enabled, then all the tools mentioned above
will automatically switch to it.  It is not possible to write data
with group access when the data folder does not use it, as well as
to write data without group access when the data folder uses group
access.  So all the behaviors are kept consistent for simplicity.

For developers of tools and plugins in charge of writing data for a
data folder or anything related to PostgreSQL, there is a simple
way to track if group access is enabled on an instance.  First,
if you use a normal libpq connection, it is possible to check after
data\_directory\_mode using the SHOW command (works as well with
the replication protocol!).  For tools working directly on a data
folder, like pg\_rewind or pg\_resetwal, there is a new API
available called GetDataDirectoryCreatePerm() which can be used to
set a couple of low-level variables which would set the mask needed
for files and folders automatically:

  * pg\_mode\_mask for the mode mask, usable with umask().
  * pg\_file\_create_mode, for file creation mask.
  * pg\_dir\_create_mode, for directory creation mask.

So you may want to patch your tool so as this is made extensible in a
way consistent with PostgreSQL 11 or newer versions.

One last thing.  Be careful of SSL certificates or such in the data
folder when allowing group access as it could result in errors with
the software doing the backup.  Fortunately those can be located outside
the data folder.
