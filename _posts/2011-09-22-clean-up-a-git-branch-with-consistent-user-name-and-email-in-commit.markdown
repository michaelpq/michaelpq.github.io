---
author: Michael Paquier
comments: false
date: 2011-09-22 07:14:58+00:00
layout: post
slug: clean-up-a-git-branch-with-consistent-user-name-and-email-in-commit
title: Clean up a GIT branch with consistent user name and email in commit
wordpress_id: 517
categories:
- Linux
tags:
- branch
- clean up
- commit
- current
- email
- filter
- filter-branch
- git
- name
- update
- user
---

Here is a shortcut to correct all the commits of a branch and set them to a specific user name and user email.
This does not correct commit messages in themselves.
Replace $USER_NAME by the user name and $USER_EMAIL by the email wanted.

    git filter-branch --env-filter 'export GIT_AUTHOR_EMAIL="$USER_EMAIL";GIT_AUTHOR_NAME="$USER_NAME"'

This command checks the author name and email and rewrites all the commits one-by-one. Current branch be rewritten with new data so may differ from a remote branch.
