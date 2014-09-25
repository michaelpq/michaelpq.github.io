---
author: Michael Paquier
date: 2013-01-03 12:08:04+00:00
layout: page
type: page
slug: ArchLinux - nginx
title: nginx
tags:
- web
- server
- archlinux
- nginx
- configuration
- deployment
- automate
---
nginx is an excellent alternative to move out from Apache. Here are
some notes to set up nginx correctly.

### Prevent DDOS

DDOS (Distributed deny of service) can be easily avoided by limiting
the number of connections from a given IP with such settings in a
server block.

    http {
        limit_conn_zone $binary_remote_addr zone=addr:10m;
        server {
            ...
            location /download/ {
            limit_conn addr 1;
        }
    }

### Subdomain settings

This can be achieved with multiple server blocks.

    server {
        listen   80;
        server_name  sub1.example.com;
        access_log  /var/log/nginx/sub1.access.log;
        location / { 
            root   /home/site/sub1; 
            index  index.html index.htm; 
        }
    }
    server {
        listen   80;
        server_name  sub2.example.com;
        access_log  /var/log/nginx/sub2.access.log;
        location / { 
            root   /home/site/sub2; 
            index  index.html index.htm; 
        }
    }

### Blog with toto

Here is a sample of configuration file for nginx.conf.

    upstream toto {
        server 127.0.0.1:3000;
    }
    
    server {
        listen   80;
        server_name  www.example.com;
        rewrite ^/(.*) http://example.com permanent;
    }
    
    server {
        listen   80;
        server_name example.com;

        access_log $HOME/log/access.log;
        error_log $HOME/log/error.log;
    
        root   $HOME/blog/;
        index  index.html;
    
        location / {
            proxy_set_header  X-Real-IP  $remote_addr;
            proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header Host $http_host;
            proxy_redirect false;
    
            if (-f $request_filename/index.html) {
                rewrite (.*) $1/index.html break;
            }
    
            if (-f $request_filename.html) {
                rewrite (.*) $1.html break;
            }
    
            if (!-f $request_filename) {
                proxy_pass http://toto;
                break;
            }
        }
    }
