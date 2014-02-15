---
author: Michael Paquier
comments: false
date: 2011-07-23 14:19:17+00:00
layout: post
type: post
slug: creating-private-git-repositories-in-shared-hosting-environment
title: Creating private GIT repositories in shared hosting environment
wordpress_id: 435
categories:
- Linux-2
tags:
- apache
- cgi
- cvs
- developer
- environment
- error
- git
- gitphp
- group
- htaccess
- php
- private
- programing
- project
- repack
- repository
- rewrite
- shared hosting
- upload
- user
---

Developers are sometimes looking for cheap solutions to have their own private repositories. There are multiple solutions for open source software such as [source forge](http://sourceforge.net) or [GitHub](http://github.com/) that can provide wide and secured functionalities. However, in the case of the 1st solution it is not possible to create private repositories, and in the second case private repositories are possible but this solution is not worth the money for independant programmers.

The cheapest solution remains in having its own hosting service (buying a domain, creating a free domain, etc). Google that will for sure lead you to free services with dedicated domain names for example.

Most of the time such hosting services are shared-hosting based. This means that multiple users are using the same server for their websites. In this case normal users do not have root rights (well, normal!), so it is impossible to make fine settings of the configuration files of apache, like httpd.conf.

GIT supports http protocol for its repositories for a long time, but the original protocol uses WebDAV and is really heavy and slow. Roughly, you needed to send to remote server entire files and not diffs. However, since version 1.6.6, GIT supports smart HTTP protocol, this has speed up http repositories and you do not even need WebDAV. An important point, WebDAV can be activated in httpd.conf of your apache server with the keywords "DAV On" but this creates an error, that's why the solution presented here only uses smart http.

So, to set your GIT repositories, what is needed first is GIT installed on your server.

    git --version
    git version 1.7.0.4

The important point is to have support of the command git-http-backend.

This done, you also need the apache modules mod_cgi, mod_alias, and mod_env to be activated.

Now, let's go through the whole setting process. In the case of this tutorial, our goal is to create a private repository for a project called foo-project. The private repositories that will be set are protected in read and write by apache group management.

From the root repository of your domain http://www.example.com/, if you have a connection through ssh, go to the root repository that should be called public_html. Then type the following command:

    htpasswd -c .htpasswd user-name

You can also do that in another folder or in a subdomain of course.

You will be requested to write a password. This command will create a file called .htpasswd containing data like this:

    user-name: $encrypted-passwd

"user-name" can be the name you want. It is an apache-level security group, so if you want you don't need to use the same user name as your Linux session. This file contains user and password data for the access to private repositories.

It is possible to add new users to this file with commands like:

    htpasswd .htpasswd new-user-name

Then create a file called .htgroup. It contains the following data:

    foo_write: user-name new-user-name

This file will be used to control the group data of apache. You can create for each private repository a group with a list of users. One line has to be used for each group. Keep in mind that it is easier to maintain the group list in a common file. However you can set group file in different files if you wish. Just don't forget to list those files in appropriate .htaccess files.

Then it is time to create the access control to private repositories. Create a folder called git in the root folder public_html and move in it:

    mkdir git
    cd git

There you need to create a new CGI script that will be used to rewrite requested URL for private GIT repositories. With an editor, create a file called git-http-backend.cgi with the following data in it.

    #!/bin/sh
    #first we export the GIT_PROJECT_ROOT
    export GIT_PROJECT_ROOT=/to/site/folder/public_html/git/

    if [ -z "$REMOTE_USER" ]
    then
        export REMOTE_USER=$REDIRECT_REMOTE_USER
    fi

    #and run your git-http-backend
    /usr/bin/git-http-backend

GIT_PROJECT_ROOT is an environment variable pointing to the root folder of your GIT repositories. A mistake here may lead to an error 500...

Depending on the server of your shared hosting service, git-http-backend may not be in /usr/bin/ but in /usr/lib/git-core/ or whatever. Be sure to check where it is with the command:

    which git-http-backend

Then create an .htaccess file in git to control URL rewrite. It contains the data:

    Options +ExecCgi

    #This is used for group/user access control
    AuthName "Private Git Access"
    AuthType Basic
    AuthUserFile /to/site/folder/public_html/.htpasswd
    AuthGroupFile /to/site/folder/public_html/.htgroup
    Require valid-user

    #This is the rewrite algorithm
    RewriteEngine on
    RewriteBase /git
    SetHandler cgi-script
    RewriteRule ^([a-zA-Z0-9._]*\.git/(HEAD|info/refs|objects/(info/[^/]+|[0-9a-f]{2}/[0-9a-f]{38}|pack/pack-[0-9a-f]{40}\.(pack|idx))|git-(upload|receive)-pack))$ /git/git-http-backend.cgi/$1`

Then it is time to create the GIT repository of foo-project and move in it.

    mkdir foo-project.git
    cd foo-project.git

Now you should be in folder /to/site/folder/public_html/git/foo-project.git.

Then initialize your GIT repository with the following commands.

    git --bare init
    git --bare update-server-info
    cp hooks/post-update.sample hooks/post-update
    chmod a+x hooks/post-update
    touch git-daemon-export-ok

This basically makes all the necessary settings to allow your folder to use smart http mode. If you don't care about GIT details, just copy/paste that!

What finally remains is to create an .htaccess file in public_html/git/foo-project.git to control access to this repository.

    Allow from all
    Order allow,deny
    #foo_write is the group is .htgroup. All the users of this group will be authorized to access this repository at will.
    Require group foo_write

The setting on remote side is done. So now, here is how to access to the remote from your local machine.
You may either clone the new git repository.

    git clone http://www.example.com/git/foo-project.git

Or add a remote URL.

    mkdir myproject
    cd myproject
    git init
    git remote add myproj http://www.example.com/git/foo-project.git
    git fetch myproj

It may be necessary to install the library curl and set the file called .netrc in your home repository (accessible with $HOME/.netrc) like this:

    machine www.example.com
    login user-name
    password $mypasswd

If you don't want to use .netrc file you can directly add you user name in the remote URL.

    http://www.example.com/git/foo-project.git

Becomes

    http://**user-name**@example.com/git/foo-project.git

In this case you will be requested a password each time you interact with the remote folder. This is annoying so you should stick with curl.

Then, manage your folder as you always do. First begin by pushing your first commits to your newly-made repository. Here is an example:

    echo "My first commit" > README
    git add README
    git commit -a
    git push origin master

When pushing to your repository, you may find upload package errors. A common message is:

    error: unpack failed: unpack-objects abnormal exit

Don't panic. You made it well. It should not occur normally but it may happen in certain environments. This is a write permission issue. Be sure to have the repository "objects" set with correct write permissions to allow a push to be written correctly in remote repository.

An additional tip...
There are also a nice pure php solution to allow you to have a gitweb-like service in pure PHP.
[GitPHP](http://gitphp.org/projects/gitphp/wiki) is a web frontend for git repositories. This is extremely handy in a shared hosting environment as you do not need to set httpd.conf and you don't need root rights on your server.
