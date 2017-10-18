---
author: Michael Paquier
date: 2014-09-20 05:13:59+00:00
layout: page
type: page
slug: archlinux
title: 'Archlinux - Coding'
tags:
- manual
- linux
- tips
- coding
- development
- archive
- installation
- scratch
- experience

---

### Data type lengths

On 32-bit and 64-bit machines, the length of the following standard
variables vary, here is a list of them with their associated length.

    Environment type  32 bit    64 bit
    short int         16 bit    16 bit
    int               32 bit    32 bit
    long int          32 bit    64 bit
    long long int     64 bit    64 bit
    size_t            32 bit    64 bit
    void*             32 bit    64 bit

### Detect openssl version

openssl version can be found by using SSLeay_version in libcrypto.so, and
this function can be found for example directly by using dlsym in the
library libcrypto.so or even dylib. Here is a simple example of code able to
do so.

    #include <stdio.h>
    #include <dlfcn.h>

    typedef const char *(*SSLEAY_VERSION)(int t);

    int main(int argc, char* argv[])
    {
        void *lib;
        SSLEAY_VERSION SSLeay_version;

        /* Sanity check */
        if (argc != 2)
        {
            printf("USAGE: %s /path/to/libcrypto.so\n", argv[0]);
            return 1;
        }

        /* Try to open library given by user */
        lib = dlopen(argv[1], RTLD_NOW);
        if (lib == NULL)
        {
            printf("%s\n", dlerror());
            return 1;
        }

        /* Grab the object wanted, here openssl version function */
        SSLeay_version = (SSLEAY_VERSION) dlsym(lib, "SSLeay_version");
        if (SSLeay_version == NULL)
        {
            printf("%s\n", dlerror());
            dlclose(lib);
            return 1;
        }
        printf("SSL version %s\n", SSLeay_version(0));

        /* Clean up */
        dlclose(lib);
        return 0;
    }

Compile this code for example like that and then it is simple to use:

    $ gcc -g -o openssl_version openssl_version.c -ldl
    $ openssl_version /path/to/libcrypto.[so|dylib]
    SSL version OpenSSL 1.0.1h-fips 5 Jun 2014

Actually this trick with dlsym can be used on any functions for any library,
just be sure that library dependencies are covered when compiling the code.

# Kernel configuration

Here is a set of custom files used with Archlinux to customize many things
in /etc/sysctl.d/

    $ cat core_pattern.conf
    # Core file pattern in case of a SIGSEV.
    kernel.core_pattern = core.%e.%p
    $ cat oom.conf
	# Only swap +50% of memory that can be handled by applications. Useful
	# to not freeze a laptop when debugging memory allocation problems on
	# an application.
    vm.overcommit_memory = 2
    vm.overcommit_ratio = 50
    $ cat perf_settings.conf
    # Allow all perf events to be taken
    kernel.perf_event_paranoid = -1
    $ cat ptrace.conf
	# Allow initialization of gdb to attach to a process.
    kernel.yama.ptrace_scope = 0
