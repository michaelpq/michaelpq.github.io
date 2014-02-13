---
author: Michael Paquier
date: 2013-07-21 01:15:25+00:00
layout: page
type: page
slug: jenkins
title: Jenkins
tags:
- manual
- michael
- paquier
- jenkins
- install
- deployment
- manage
- server
- automate
- test
- settings
- linux
- ssl
---
This manual describes how to install and manage a Jenkins server using a fresh server based on Ubuntu 12.04. Why this OS? Because it looks to be the faster in term of settings, at least as far as I tested, and it is going to be maintained until 2017 as an LTS. The server version is used.

#### Install latest version of git manually

    wget git-core.googlecode.com/files/git-1.8.3.3.tar.gz
    tar -zxf git-1.8.3.3.tar.gz
    cd git-1.8.3.3
    make prefix=$HOME/bin/extra/git all
    make prefix=$HOME/bin/extra install`
    With libssl-dev, libcurl-ssl-dev, libexpat1-dev, gettext.

#### Install jenkins

Jenkins has created a dedicated user jenkins, and will work with port 8080. You should as well be able to connect to it in a browser with this URL.

    apt-get install jenkins

#### General settings and plugins

Once you have confirmed connection to Jenkins, enable the security on it and manage it with users. Go to "Manage Jenkins" -> "Configure System" -> "Enable security". Then choose:

  * Security Realm -> "Jenkins's own user database" and "allow users to sign up"
  * Authorization -> put "Anyone can do anything for the time being"

Then sign up with your user account. Finally change to "Matrix-based security", give all the rights to your user, and read-only to Anonymous. Finally Disable "Allow users to sign up". If you do an error here, change manually /var/lib/jenkins/config.html: change "useSecurity" to false and delete "authorizationStrategy" part to return to the former settings.

Next, install the git plugin (you will need to install git when launching projects). Go to "Manage Jenkins" -> "Plug-ins", and install "Git Plugin".

Also set up that for new user Jenkins:

    git config --global user.email "jenkins@example.com"
    git config --global user.name "Jenkins"

#### Setup for Postgres

The goal is to be possible to install Postgres with the following set of options.
    ./configure --enable-cassert --enable-debug --enable-nls --enable-integer-datetimes \
        --with-perl --with-python --with-tcl --with-krb5 \
        --with-includes=/usr/include/et --with-openssl --with-ldap \
        --with-libxml --with-libxslt

Here is the raw list of necessary packages for the base:

    make bison flex gcc zlib1g-dev libssl-dev libreadline-dev libxml2-dev libxslt1-dev tcl-dev libperl-dev python-dev

For the documentation:

    jade
    openjade
    docbook-dsssl
    docbook
    docbook2x
    docbook-xsl

And that:

    export DOCBOOKSTYLE=/usr/share/sgml/docbook/stylesheet/dsssl/modular

Then create a new project and set the following:

  * "Source Code Management" to "Git"
  * "Add a build step", set to ./configure + make world combination

Then you can schedule things as wanted. Based on the success of this build, you can trigger other builds and tests. The files fetched by git are installed in /var/lib/jenkins/jobs/$BUILD_NAME.

#### CentOS

It is important to install the development distribution to save a lot of time. Addition of Epel repository:

    wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
    wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
    sudo rpm -Uvh remi-release-6*.rpm epel-release-6*.rpm

Open port 8080 in firewall (iptables). Need to edit /etc/sysconfig/iptables with this line:

    -A INPUT -m state --state NEW -m tcp -p tcp --dport 8080 -j ACCEPT

Install Jenkins:

    wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo
    rpm --import http://pkg.jenkins-ci.org/redhat/jenkins-ci.org.key
    yum install jenkins
