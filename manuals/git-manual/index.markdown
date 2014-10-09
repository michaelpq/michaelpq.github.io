---
author: Michael Paquier
date: 2011-02-28 13:01:45+00:00
layout: page
type: page
slug: git-manual
title: GIT Manual
tags:
- git
- manual
- tip
- general
- idea
- branch
- tag
- push
- remote
- repository
- clone
- fetch
- michael
- paquier
- patch
- manage
- cvs
---
Git is a code tree management largely present in many development teams.
Have a look also [here](http://git-scm.com/).

### 1. How to get a GIT code repository

Make everything automatically with git clone.

    git clone git://$URL

You can also use this step-by-step method:

    git init
    git remote add $PROJECT_NAME $GIT_URL
    git fetch $PROJECT_NAME
    git branch --track $LOCAL_BRANCH_NAME $PROJECT_NAME/$REMOTE_BRANCH_NAME
    git checkout master

  * PROJECT_NAME is the local name of the url leading to remote
repository. Feel free to choose something appealing to you.
  * GIT_URL is the url to remote git repository.
  * LOCAL_BRANCH_NAME is the name of the branch you want to track locally.
  * REMOTE_BRANCH_NAME is the name of the remote branch in remote
repository you want to target.

### 2. How to set up your environment

Before beginning your work, be sure that your environment is setup
according to your tastes. Some people love vi more than emacs. Some
Linux distributions use as editor nano by default. In case you want
to set up parameters for your whole user system, use git config --global.
How to set a prefered editor:

    git config --global core.editor "vi"

or

    git config --global core.editor "emacs"

Depending on which one you like. A recommandation is to set up push.default
at current. With that you only push to repository the branch where you are
currently.

    git config push.default current [change the mode used for push]

There are 4 modes:

  * 'nothing'  : Do not push anything
  * 'matching' : Push all matching branches (default)
  * 'tracking' : Push the current branch to whatever it is tracking
  * 'current'  : Push the current branch

Another recommendation: setup the following parameters to control what
you commit and identify yourself as the committer.

    git config --global user.name "John Doe"
    git config --global user.email "john-doe@doe.com"

### 3. Now that you have the code, and that you have set you environment,

You want to interact with it, no? Here is how to play with branches and
code in your local repository. Try to modify some files, and save them.
Make a commit by involving in the commit all the files modified. (This
involves just existing files modified. In order to add all the files,
you have to make a "git add *").

    git commit -a

After creating new files, they have to be tracked with this.

    git add $file

On the contrary, to stop tracking a file and delete it.

    git rm $file

To see the status of what can be committed (at the moment of entering
this command).

    git status

### 4. Branches

Print out a list of all the existing branches (* marks the current branch
being developed).

    git branch -a

Create a new branch in local repository from a chosen start point.

    git branch $NEW_BRANCH_NAME $START_POINT

START_POINT can be a branch name, a commit ID, or a tag name. Checkout
a chosen local branch.

    git checkout $BRANCH_NAME

If you want to create a branch and then to check it out.

    git branch $NEW_BRANCH_NAME $START_POINT
    git checkout $NEW_BRANCH_NAME

To delete a local branch.

    git branch -D $BRANCH_NAME

To rename a local branch.

    git branch -M $OLD_BRANCH_NAME NEW_BRANCH_NAME

Get diff between branches, commit IDs or tags.

    git diff $POINT_DIFF_BASE $POINT_DIFF_COMPARE

This is useful to generate patches based on a master branch for instance.
Have a look at the last commits done in named branch.

    git log -p $BRANCH_NAME (all diffs also appear)
    git log $BRANCH_NAME
    git log $BRANCH_NAME --name-only (only file names appear)

Not naming a branch is equivalent to print logs of current branch. This
is helpful to get commit IDs. You can also apply a patch in a GIT
repository.

    git apply $PATCH

Sometimes after fetching the latest data of a remote repository locally,
it may happen that a branch deleted on remote is still listed locally. To
delete a remote branch listed locally:

    git branch -rd $PROJECT_NAME/$BRANCH_NAME

Check which branches contain a given commit.

    git branch --contains $COMMIT_ID

Assigning a description to a branch is useful to keep track on the work
being done on a bug or a feature. To set a description run this command
that will open an editor:

    git branch --edit-description

It may be useful to use that to keep notes of what was being done, like
future plans, next steps or remaining tasks. It is then possible to read
again the description saved previously with this command:

    git config branch.$BRANCH_NAME.description

### 5. Play with branches in remote repository

This will push your local branch BRANCH_NAME to your remote project
whose URL is PROJECT_NAME.

    git push $PROJECT_NAME $BRANCH_NAME

The name of branch created on remote is the same as your local branch
name. In the case of not using the same branch name on the remote
repository, here is a magic command.

    git push $PROJECT_NAME $LOCAL_BRANCH_NAME:$REMOTE_BRANCH_NAME

If you want to delete a branch called BRANCH_NAME in your remote
repository.

    git push $PROJECT_NAME :$BRANCH_NAME

After pushing a new branch in remote repository, the local branch you
pushed will lose tracking of the branch that is now in remote.

    git branch -f $LOCAL_BRANCH_NAME $PROJECT_NAME/$REMOTE_BRANCH_NAME

This forces local branch to track the new remote one. It cannot be
done on current branch.

### 6. Interacting with tags:

Git commit system is very powerful, you can find all the necessary
information about a project state easily. But sometimes a programmer
wants to put a mark in his project so as to show that an important
step has been done. Tags can play a role to associate a commit in
a branch with a tag name. Create a tag:

    git tag -a $TAG_NAME -m "message" $COMMIT_OF_TAG

If multiple m options are used, messages are written as separate
paragraphs. Show all the existing tags and their associated message.
COMMIT\_OF\_TAG is as well not mandatory, just useful to avoid creating
a new local exatr branch just to create a dedicated tag on a given point.

    git tag -l -n

Push to remote repository all the tags.

    git push --tags

Push to remote repository the tag chosen.

    git push $PROJECT_NAME $TAG_NAME

Delete a tag in local repository.

    git tag -d tagname

Delete a tag in remote repository:

    git push PROJECT_NAME :TAG_NAME

Display local and remote tags.

    git tag -l

### 7. About rebase

Here is a basic process to rebase on a branch called $BRANCH_CURRENT a
set of n last commits pointed by $CURRENT_HEAD_OF_PATCHES (being a tag,
a commit ID or a branch head). By being on a branch called $BRANCH_CURRENT,
first checkout a temporary branch:

    git checkout -b tmp

Then force the branch to be rebased to move to the head of commit set
(last commit from the set of n patches wanted to be rebased).

    git branch -f $BRANCH_CURRENT $CURRENT_HEAD_OF_PATCHES

Then make the rebase, take the last n commits from head of patches to
be rebased.

    git rebase --onto tmp $CURRENT_HEAD_OF_PATCHES~N $BRANCH_CURRENT

There will be for sure conflicts when you rebase $BRANCH_CURRENT, in
this case it is necessary to treat them one by one.

    git rebase --continue

Makes rebase continue to the next conflict.

    git rebase --abort

Stops rebase.

    git rebase --skip

Skip this conflict. Once a conflict is solved on a file, do not forget
to add it with "git add" before continue rebase. The interactive mode
is useful as well and far more flexible if you need to edit, amend or
merge a couple of commits during the rebase.

    git rebase --interactive $BRANCH_NAME

When only few commits are being moved, git cherry-pick is also useful.
For example, by being on $CURRENT_BRANCH:

    git cherry-pick master~1 master~4

Takes the 2nd and 5th latest commits applied on master and creates 2 new
commits on $CURRENT_BRANCH.

### 8. Patch management

Generate a patch based on diffs between two branches.

    git diff $CURRENT_BRANCH $DIFF_BRANCH > $FOLDER/patch_name.patch

Check statistics of this patch if applied.

    git apply --stat $FOLDER/patch_name.patch

Check if patch can be correctly applied.

    git apply --check $FOLDER/patch_name.patch

Apply a patch.

    git apply $FOLDER/patch_name.patch

Generate a patch with context diff (needs package patch-utils).

    git diff $DIFF1 $DIFF2 | filterdiff --format=context

### 9. Clean up a repository with not-wanted data

Change all the author names and emails of a branch, and rewrite this branch.

    git filter-branch --commit-filter 'if [ "$GIT_AUTHOR_NAME" == "Your name to change" ];
    then export GIT_AUTHOR_NAME="New name"; export GIT_AUTHOR_EMAIL=name@example.com;
    fi; git commit-tree "$@"'

Remove all the untracked files.

    git clean -d -x -n

-n is for a dry run, so it shows what would be removed. Replace -n
by -f to really remove the untracked elements. -d includes repositories,
-x for files ignored by git.

### 9. bisect

A bisect processing uses dychotomy to find culprit commits in a git
repository. This first begins with this command:

    git bisect start $BAD_COMMIT $GOOD_COMMIT

BAD_COMMIT is a newer commit that introduced the error since GOOD_COMMIT
that should be an older commit. It is as well possible to use the following
commands to define good and bad commits (HEAD is used if nothing is
specified):

    git bisect good $COMMIT
    git bisect bad $COMMIT

Then process can be run to determine the commit introducing any regression.
This can be done with the following command:

    git bisect run $COMMAND

COMMAND should actually be a script that returns an exit code that help
bisect to define if the commit tested is good or bad. Code 0 should be
used for a good code. Code 1-127 can be used to define a bad code. 125
is a special exit code that can be used to make the commit as untestable.

When bisect analysis is finished, use that to finish the process:

    git bisect reset

### 10. Maintenance

It is recommended to use fsck to check the validity of the database.

    git fsck

After doing some work, it is possible that you created some dangling
commits, which are commits not referenced by any existing branches.
Those ones are by default reported by fsck. Removing them can be done
with the following command:

    git gc --prune=now

### 11. History

reflog helps to track the history of the actions that occurred on
a local repository in the order they have occurred when applied. So
for example HEAD@{N} means the position where HEAD was N moves ago.

    git reflog [show]

Deleting entried in the reflog is possible with this command:

    git reflog delete $REFERENCE

### 12. Hooks

Here are some hooks facilitating the life of developers. Note that
hooks need to be made executable.

Hook to update all the submodules after a branch checkout. Save it
as .git/hooks/post-checkout.

    #!/bin/bash
    # Update submodules after a branch checkout
    CURRENT_FOLDER=`pwd`

    # Move to the root of this folder
    cd `git rev-parse --show-toplevel`

    # After a checkout, enforce an update of submodules for this folder
    git submodule update --init --recursive

    # Move back to current folder
    cd $CURRENT_FOLDER

You can as well test if code compiles correctly after a patch by
creating a pre-push hook running the compile commands. Save it as
.git/hooks/pre-push.

### 13. submodules

A submodule consists of a soft link in a Git repo to another repository,
defined on parent by a path and a commit ID. Since git 1.8.3, a branch can
as well be given to synchronize a submodule based on the latest commit of
a branch. Here is a way to initialize everything easily:

    git submodule update --init --recursive

Watch the status of the submodules.

### 14. Migration

Transferring a CVS repository to a GIT one is pretty simple.

You need first to install the following packages: git-cvs cvsps. In
ArchLinux, git-cvs is lacking of support in ArchLinux, so I used an
RPM-based box.

    yum install git-cvs cvsps

Then, simply run the following command in a given folder $FOLDER.

    mkdir $FOLDER
    cd $FOLDER
    git cvsimport -v -d :pserver:anonymous@example.com:/sources/classpath \
        $MODULE_NAME
