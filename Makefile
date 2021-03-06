# This Makefile is used to help drive the installation of mod_pagespeed into
# an Apache installation.
#
# Note that the location of the Apache configuration files may vary by
# Linux distribution.  For example, we have seen the following installation
# directories for the default Apache install.
#
#     Ubuntu 				/etc/apache2/mods-enabled/*.conf
#     CentOS 				/etc/httpd/conf.d/*.conf
#     Custom Apache build from source	/usr/local/apache2/conf/extra/
#
# In the case of the custom Apache build, you must also edit
# /usr/local/apache2/conf to add "Include conf/extra/pagespeed.conf"
#
# The goal of this Makefile is to help generate basic default
# configuration files that can then be edited to tune the HTML
# performance based on the Apache installation, internet-visible
# hostnames, and the specific needs of the site.
#
# The usage model of this Makefile is that, as an unpriviledged user, you
# create the desired configuration files in /tmp, where you can examine
# them before installing them.  You can then do either of these:
#
#    (a) Run "make -n install" to see the recommended installation commands,
#        and execute them by hand
#    (b) Run "sudo make install" to install them automatically.
#
#
# To install mod_pagespeed properly, we need to know the locations of
# Apache configuration scripts and binaries.  These can are specified
# as Makefile variables which can be overridden on the command line.
# They have defaults, which will often need to be changed.


# The location of the Apache root installation directory.  This helps form
# defaults for other variables, but each of those can be overridden.
APACHE_ROOT = /app/apache

# The installation directory for modules (mod*.so)
APACHE_MODULES        = $(APACHE_ROOT)/modules

# The root directory Apache uses for serving files.
APACHE_DOC_ROOT       = /app/www
# The domain Apache is serving from
#APACHE_DOMAIN        = localhost:8080  # For test-server.
APACHE_DOMAIN         = localhost
APACHE_HTTPS_DOMAIN   = localhost
APACHE_PORT           = 80
APACHE_SECONDARY_PORT = 8084
APACHE_TERTIARY_PORT  = 8085
SSL_CERT_DIR          = /etc/ssl/certs
SSL_CERT_FILE_COMMAND =

# These are set via command-line when run via 'ubuntu.sh', 'centos.sh',
# or 'opensuse.sh'.  However during development we use this Makefile
# directly, so we set defaults from an Ubuntu version on our dev
# boxes (whose Apache lacks 'graceful-stop').
APACHE_CONTROL_PROGRAM   = /etc/init.d/httpd
APACHE_START             = $(APACHE_CONTROL_PROGRAM) start
APACHE_STOP_COMMAND      = stop
APACHE_PIDFILE           = /var/run/apache2.pid
APACHE_PROGRAM           = /usr/sbin/apache2

# For testing proxying of an external domain, this represents the domain we
# are proxying from.
TEST_PROXY_ORIGIN ?= modpagespeed.com
export TEST_PROXY_ORIGIN

# The installation directory for executables
BINDIR = /app/bin

# A temp directory to stage generated configuration files.  This must be
# writable by the user, and readable by root.
STAGING_DIR = /tmp/mod_pagespeed.install

# The mod_pagespeed module is specified relative to the install directory,
# which is src/install.
MOD_PAGESPEED_ROOT = $(shell dirname `pwd`)
PAGESPEED_MODULE = $(MOD_PAGESPEED_ROOT)/out/Release/libmod_pagespeed.so
PAGESPEED_MODULE_24 = $(MOD_PAGESPEED_ROOT)/out/Release/libmod_pagespeed_ap24.so
PAGESPEED_JS_MINIFY = $(MOD_PAGESPEED_ROOT)/out/Release/js_minify

# On systems dervied from the NCSA configuration files by Rob McCool,
# you enable a module by writing its .conf file into
# $(APACHE_ROOT)/mods-available/pagespeed.conf, and a single Load command into
# $(APACHE_ROOT)/mods-enabled/pagespeed.conf.  So if that exists, then we'll
# try to automate that.
MODS_ENABLED_DIR = $(shell if [ -d $(APACHE_ROOT)/mods-enabled ]; then \
	echo $(APACHE_ROOT)/mods-enabled; fi)
MODS_AVAILABLE_DIR = $(shell if [ -d $(APACHE_ROOT)/mods-available ]; then \
	echo $(APACHE_ROOT)/mods-available; fi)

# Determines where mod_pagespeed should put cache.
MOD_PAGESPEED_CACHE = /var/cache/mod_pagespeed

# Determines where mod_pagespeed should write various logs.
MOD_PAGESPEED_LOG = /var/log/pagespeed

# The username used to run apache.  This is needed to create the directory
# used to store mod_pagespeed files and cache data.
APACHE_USER = daemon

# Set this to 1 to enable mod_proxy and mod_rewrite
ENABLE_PROXY = 0

.PHONY : config_file echo_vars

echo_vars :
	@echo Run "restart" to add default instaweb config to apache
	@echo Or run "stop", "staging", "install", and "start".
	@echo These configuration variables can be reset on the make command line,
	@echo e.g. \"make config_file\"
	@echo ""
	@echo "   APACHE_CONF=$(APACHE_CONF)"
	@echo "   APACHE_MODULES=$(APACHE_MODULES)"
	@echo "   APACHE_ROOT=$(APACHE_ROOT)"
	@echo "   APACHE_START=$(APACHE_START)"
	@echo "   APACHE_STOP_COMMAND=$(APACHE_STOP_COMMAND)"
	@echo "   MOD_PAGESPEED_CACHE=$(MOD_PAGESPEED_CACHE)"
	@echo "   MOD_PAGESPEED_LOG=$(MOD_PAGESPEED_LOG)"
	@echo "   MODS_ENABLED_DIR=$(MODS_ENABLED_DIR)"
	@echo "   MODS_AVAILABLE_DIR=$(MODS_AVAILABLE_DIR)"
	@echo "   STAGING_DIR=$(STAGING_DIR)"
	@echo "   ENABLE_PROXY=${ENABLE_PROXY}"
	@echo "   SLURP_DIR=${SLURP_DIR}"
	@echo "   SHARED_MEM_LOCKS=${SHARED_MEM_LOCKS}"


# In some Linux distributions, such as Ubuntu, there are two commands
# in the default root config file:
#    Include /etc/apache2/modes-enabled/*.load
#    Include /etc/apache2/modes-enabled/*.conf
# we need to write a one-line '.load' file and put that and our '.conf' file
# into .../mods-enabled.
#
# In other distributions, such as CentOS, there is an 'Include DIR/*.conf',
# but there is no implicit loading of modules, so we write our Load line
# directly into our config file.

# In either case, independent configuration files go here (this directory
# is read by both distributions on startup after the modules load).
APACHE_CONF_D = $(APACHE_ROOT)/conf

ifeq ($(MODS_ENABLED_DIR),)

# This is a CentOS-like installation, where there is no explicit .load
# file, and we instead pre-pend the LoadModule command to the .conf file.
APACHE_CONF = $(APACHE_CONF_D)
CONF_SOURCES = $(STAGING_DIR)/pagespeed.load $(STAGING_DIR)/pagespeed.conf

else

# This is an Ubuntu-like installation, where the .load files are placed
# separately into a mods-enabled directory, and the .conf file is loaded
# independently.
MODS_ENABLED_INSTALL_COMMANDS = \
	rm -f $(MODS_ENABLED_DIR)/pagespeed.load ; \
	cp -f $(STAGING_DIR)/pagespeed.load $(MODS_AVAILABLE_DIR) ; \
	cd $(MODS_ENABLED_DIR) && ln -s ../mods-available/pagespeed.load ; \
	rm -f $(MODS_ENABLED_DIR)/headers.load ; \
	cd $(MODS_ENABLED_DIR) && ln -s ../mods-available/headers.load ; \
	rm -f $(MODS_ENABLED_DIR)/deflate.load ; \
	cd $(MODS_ENABLED_DIR) && ln -s ../mods-available/deflate.load

APACHE_CONF = $(MODS_AVAILABLE_DIR)
CONF_SOURCES = $(STAGING_DIR)/pagespeed.conf

endif


# We will generate 'proxy.conf' in the staging area
# unconditiontionally, but we will load it into the
# Apache server only if the user installs with ENABLE_PROXY=1
ifeq ($(ENABLE_PROXY),1)
CONF_SOURCES += $(STAGING_DIR)/proxy.conf
endif

APACHE_SLURP_READ_ONLY_COMMAND=\#ModPagespeedSlurpReadOnly on

ifeq ($(SLURP_DIR),)
  APACHE_SLURP_DIR_COMMAND = \#ModPagespeedSlurpDirectory ...
else
  APACHE_SLURP_DIR_COMMAND = ModPagespeedSlurpDirectory $(SLURP_DIR)
  ifeq ($(SLURP_WRITE),1)
    APACHE_SLURP_READ_ONLY_COMMAND=ModPagespeedSlurpReadOnly off
  else
    APACHE_SLURP_READ_ONLY_COMMAND=ModPagespeedSlurpReadOnly on
  endif
endif

ifeq ($(STRESS_TEST),1)
  # remove prefix
  STRESS_TEST_SED_PATTERN=^\#STRESS
else
  # remove whole line
  STRESS_TEST_SED_PATTERN=^\#STRESS.*\n
endif

ifeq ($(REWRITE_TEST),1)
  # remove prefix
  REWRITE_TEST_SED_PATTERN=^\#REWRITE
else
  # remove whole line
  REWRITE_TEST_SED_PATTERN=^\#REWRITE.*\n
endif

ifeq ($(COVERAGE_TRACE_TEST),1)
  # remove coverage prefix
  COVERAGE_TEST_SED_PATTERN=^\#COVERAGE
else
  # remove coverage lines
  COVERAGE_TEST_SED_PATTERN=^\#COVERAGE.*\n
endif

ifeq ($(PROXY_TEST),1)
  # remove prefix
  PROXY_TEST_SED_PATTERN=^\#PROXY
else
  # remove whole line
  PROXY_TEST_SED_PATTERN=^\#PROXY.*\n
endif

ifeq ($(SLURP_TEST),1)
  # remove prefix
  SLURP_TEST_SED_PATTERN=^\#SLURP
else
  # remove whole line
  SLURP_TEST_SED_PATTERN=^\#SLURP.*\n
endif

ifeq ($(SHARED_MEM_LOCK_TEST),1)
  # remove prefix
  SHARED_MEM_LOCK_TEST_SED_PATTERN=^\#SHARED_MEM_LOCKS
else
  # remove whole line
  SHARED_MEM_LOCK_TEST_SED_PATTERN=^\#SHARED_MEM_LOCKS.*\n
endif

ifeq ($(MEMCACHED_TEST),1)
  # remove prefix
  MEMCACHED_TEST_SED_PATTERN=^\#MEMCACHED
else
  # remove whole line
  MEMCACHED_TEST_SED_PATTERN=^\#MEMCACHED.*\n
endif

ifeq ($(IPRO_PRESERVE_COVERAGE_TEST),1)
  # remove prefix
  IPRO_PRESERVE_COVERAGE_TEST_SED_PATTERN=^\#IPRO_PRESERVE_COVERAGE
else
  # remove whole line
  IPRO_PRESERVE_COVERAGE_TEST_SED_PATTERN=^\#IPRO_PRESERVE_COVERAGE.*\n
endif

ifeq ($(MEMCACHE_COVERAGE_TEST),1)
  # remove prefix
  MEMCACHE_COVERAGE_TEST_SED_PATTERN=^\#MEMCACHE_COVERAGE
else
  # remove whole line
  MEMCACHE_COVERAGE_TEST_SED_PATTERN=^\#MEMCACHE_COVERAGE.*\n
endif

ifeq ($(PURGING_COVERAGE_TEST),1)
  # remove prefix
  PURGING_COVERAGE_TEST_SED_PATTERN=^\#PURGING_COVERAGE
else
  # remove whole line
  PURGING_COVERAGE_TEST_SED_PATTERN=^\#PURGING_COVERAGE.*\n
endif

ifeq ($(IUR_COVERAGE_TEST),1)
  # remove prefix
  IUR_COVERAGE_TEST_SED_PATTERN=^\#IUR_COVERAGE
  # remove whole explicit domain authorization line
  DOMAIN_AUTH_SED_PATTERN=^\#DOMAIN_AUTH_COVERAGE.*\n
else
  # remove whole line
  IUR_COVERAGE_TEST_SED_PATTERN=^\#IUR_COVERAGE.*\n
  ifeq ($(COVERAGE_TRACE_TEST),1)
    # remove prefix for explicit domain authorization line
    DOMAIN_AUTH_SED_PATTERN=^\#DOMAIN_AUTH_COVERAGE
  endif
endif

ifeq ($(SPELING_TEST),1)
  # remove prefix
  SPELING_TEST_SED_PATTERN=^\#SPELING
else
  # remove whole line
  SPELING_TEST_SED_PATTERN=^\#SPELING.*\n
endif

ifeq ($(REWRITE_TEST),1)
  # remove prefix
  REWRITE_TEST_SED_PATTERN=^\#REWRITE
else
  # remove whole line
  REWRITE_TEST_SED_PATTERN=^\#REWRITE.*\n
endif

ifeq ($(GZIP_TEST),1)
  # remove prefix
  GZIP_TEST_SED_PATTERN=^\#GZIP
else
  # remove whole line
  GZIP_TEST_SED_PATTERN=^\#GZIP.*\n
endif

ifeq ($(EXPERIMENT_GA_TEST),1)
  # remove prefix
  EXPERIMENT_GA_TEST_SED_PATTERN=^\#EXPERIMENT_GA
else
  # remove whole line
  EXPERIMENT_GA_TEST_SED_PATTERN=^\#EXPERIMENT_GA.*\n
endif

ifeq ($(EXPERIMENT_NO_GA_TEST),1)
  # remove prefix
  EXPERIMENT_NO_GA_TEST_SED_PATTERN=^\#EXPERIMENT_NO_GA
else
  # remove whole line
  EXPERIMENT_NO_GA_TEST_SED_PATTERN=^\#EXPERIMENT_NO_GA.*\n
endif

ifeq ($(HTTPS_TEST),1)
  # remove prefix
  HTTPS_TEST_SED_PATTERN=^\#HTTPS
else
  # remove whole line
  HTTPS_TEST_SED_PATTERN=^\#HTTPS.*\n
endif

ifeq ($(ALL_DIRECTIVES_TEST),1)
  # remove prefix
  ALL_DIRECTIVES_TEST_SED_PATTERN=^\#ALL_DIRECTIVES
else
  # remove whole line
  ALL_DIRECTIVES_TEST_SED_PATTERN=^\#ALL_DIRECTIVES.*\n
endif

ifeq ($(PER_VHOST_STATS_TEST),1)
  # remove prefix
  PER_VHOST_STATS_TEST_SED_PATTERN=^\#PER_VHOST_STATS
else
  # remove whole line
  PER_VHOST_STATS_TEST_SED_PATTERN=^\#PER_VHOST_STATS.*\n
endif

ifeq ($(NO_PER_VHOST_STATS_TEST),1)
  # remove prefix
  NO_PER_VHOST_STATS_TEST_SED_PATTERN=^\#NO_PER_VHOST_STATS
else
  # remove whole line
  NO_PER_VHOST_STATS_TEST_SED_PATTERN=^\#NO_PER_VHOST_STATS.*\n
endif

ifeq ($(STATS_LOGGING_TEST),1)
  # remove prefix
  STATS_LOGGING_TEST_SED_PATTERN=^\#STATS_LOGGING
else
  # remove whole line
  STATS_LOGGING_TEST_SED_PATTERN=^\#STATS_LOGGING.*\n
endif

# Note that the quoted sed replacement for APACHE_SLURP_DIR_COMMAND is because
# that might have embedded spaces, and 'sed' is interpreted first by bash.

$(STAGING_DIR)/pagespeed.conf : common/pagespeed.conf.template debug.conf.template
	sed -e "s!@@APACHE_DOC_ROOT@@!$(APACHE_DOC_ROOT)!g" \
	    -e "s!@@APACHE_DOMAIN@@!$(APACHE_DOMAIN)!g" \
	    -e "s!@@APACHE_HTTPS_DOMAIN@@!$(APACHE_HTTPS_DOMAIN)!g" \
	    -e "s!@@APACHE_MODULES@@!$(APACHE_MODULES)!g" \
	    -e "s!@@APACHE_SECONDARY_PORT@@!$(APACHE_SECONDARY_PORT)!g" \
	    -e "s!@@APACHE_TERTIARY_PORT@@!$(APACHE_TERTIARY_PORT)!g" \
	    -e "s!@@TEST_PROXY_ORIGIN@@!$(TEST_PROXY_ORIGIN)!g" \
	    -e "s!@@MOD_PAGESPEED_CACHE@@!$(MOD_PAGESPEED_CACHE)!g" \
	    -e "s!@@MOD_PAGESPEED_LOG@@!$(MOD_PAGESPEED_LOG)!g" \
	    -e "s!@@SSL_CERT_DIR@@!$(SSL_CERT_DIR)!g" \
	    -e "s!@@SSL_CERT_FILE_COMMAND@@!$(SSL_CERT_FILE_COMMAND)!g" \
	    -e "s@# ModPagespeedSlurpDirectory ...@$(APACHE_SLURP_DIR_COMMAND)@g" \
	    -e "s@# ModPagespeedSlurpReadOnly on@$(APACHE_SLURP_READ_ONLY_COMMAND)@g" \
	    -e "s|@@TMP_SLURP_DIR@@|$(TMP_SLURP_DIR)|g" \
	    -e "s|@@MEMCACHED_PORT@@|$(MEMCACHED_PORT)|g" \
	    -e "s@$(STRESS_TEST_SED_PATTERN)@@" \
	    -e "s@$(REWRITE_TEST_SED_PATTERN)@@" \
	    -e "s@$(COVERAGE_TEST_SED_PATTERN)@@" \
	    -e "s@$(PROXY_TEST_SED_PATTERN)@@" \
	    -e "s@$(SLURP_TEST_SED_PATTERN)@@" \
	    -e "s@$(SHARED_MEM_LOCK_TEST_SED_PATTERN)@@" \
	    -e "s@$(SPELING_TEST_SED_PATTERN)@@" \
	    -e "s@$(MEMCACHED_TEST_SED_PATTERN)@@" \
	    -e "s@$(IPRO_PRESERVE_COVERAGE_TEST_SED_PATTERN)@@" \
	    -e "s@$(MEMCACHE_COVERAGE_TEST_SED_PATTERN)@@" \
	    -e "s@$(PURGING_COVERAGE_TEST_SED_PATTERN)@@" \
	    -e "s@$(IUR_COVERAGE_TEST_SED_PATTERN)@@" \
	    -e "s@$(DOMAIN_AUTH_SED_PATTERN)@@" \
	    -e "s@$(GZIP_TEST_SED_PATTERN)@@" \
	    -e "s@$(HTTPS_TEST_SED_PATTERN)@@" \
	    -e "s@$(EXPERIMENT_GA_TEST_SED_PATTERN)@@" \
	    -e "s@$(EXPERIMENT_NO_GA_TEST_SED_PATTERN)@@" \
	    -e "s@$(ALL_DIRECTIVES_TEST_SED_PATTERN)@@" \
	    -e "s@$(PER_VHOST_STATS_TEST_SED_PATTERN)@@" \
	    -e "s@$(NO_PER_VHOST_STATS_TEST_SED_PATTERN)@@" \
	    -e "s@$(STATS_LOGGING_TEST_SED_PATTERN)@@" \
		$^ > $@
	! grep '@@' $@  # Make sure we don't have any remaining @@variables@@

$(STAGING_DIR)/proxy.conf : proxy.conf.template
	sed -e s@APACHE_MODULES@$(APACHE_MODULES)@g \
		$< > $@

CONF_TEMPLATES = $(STAGING_DIR)/pagespeed.conf \
		 $(STAGING_DIR)/proxy.conf

setup_staging_dir :
	rm -rf $(STAGING_DIR)
	mkdir -p $(STAGING_DIR)

LIBRARY_CONF_SOURCE = \
    $(MOD_PAGESPEED_ROOT)/net/instaweb/genfiles/conf/pagespeed_libraries.conf

# Generate a configuration file and copy it to the staging area.
# Also copy the example tree, and the built Apache module
staging_except_module : setup_staging_dir $(CONF_TEMPLATES)
	cat common/pagespeed.load.template | \
	    sed s~@@APACHE_MODULEDIR@@~$(APACHE_MODULES)~ | \
	    sed s/@@COMMENT_OUT_DEFLATE@@// > $(STAGING_DIR)/pagespeed.load
	cp -f $(LIBRARY_CONF_SOURCE) $(STAGING_DIR)/pagespeed_libraries.conf
	$(MODS_ENABLED_STAGING_COMMANDS)
	cp -rp mod_pagespeed_example mod_pagespeed_test $(STAGING_DIR)

staging : staging_except_module
	cp $(PAGESPEED_MODULE) $(STAGING_DIR)/mod_pagespeed.so
	cp $(PAGESPEED_MODULE_24) $(STAGING_DIR)/mod_pagespeed_ap24.so
	cp $(PAGESPEED_JS_MINIFY) $(STAGING_DIR)/pagespeed_js_minify

install_except_module : mod_pagespeed_file_root
	$(MODS_ENABLED_INSTALL_COMMANDS)
	cat $(CONF_SOURCES) > $(APACHE_CONF)/pagespeed.conf
	cp -f $(STAGING_DIR)/pagespeed_libraries.conf \
	      $(APACHE_CONF_D)/pagespeed_libraries.conf
	rm -rf $(APACHE_DOC_ROOT)/mod_pagespeed_example \
	       $(APACHE_DOC_ROOT)/mod_pagespeed_test
	cp -r $(STAGING_DIR)/mod_pagespeed_example \
	      $(STAGING_DIR)/mod_pagespeed_test $(APACHE_DOC_ROOT)
#	chown -R $(APACHE_USER) $(APACHE_DOC_ROOT)/mod_pagespeed_example \
#	 			$(APACHE_DOC_ROOT)/mod_pagespeed_test

# To install the mod_pagespeed configuration into the system, you must
# run this as root, or under sudo.
install : install_except_module
	cp $(STAGING_DIR)/mod_pagespeed.so $(APACHE_MODULES)
	cp $(STAGING_DIR)/mod_pagespeed_ap24.so $(APACHE_MODULES)
	cp $(STAGING_DIR)/pagespeed_js_minify $(BINDIR)

mod_pagespeed_file_root :
#	mkdir -p $(MOD_PAGESPEED_CACHE)
#	chown -R $(APACHE_USER) $(MOD_PAGESPEED_CACHE)

#	mkdir -p $(MOD_PAGESPEED_CACHE)-alt
#	chown -R $(APACHE_USER) $(MOD_PAGESPEED_CACHE)-alt

#	mkdir -p $(MOD_PAGESPEED_LOG)
#	chown -R $(APACHE_USER) $(MOD_PAGESPEED_LOG)

flush_disk_cache :
	rm -rf $(MOD_PAGESPEED_CACHE)
	$(MAKE) MOD_PAGESPEED_CACHE=$(MOD_PAGESPEED_CACHE) \
		MOD_PAGESPEED_LOG=$(MOD_PAGESPEED_LOG) \
		APACHE_USER=$(APACHE_USER) mod_pagespeed_file_root

# Starts Apache server
start :
	sudo $(APACHE_START)
stop :
	sudo ./stop_apache.sh $(APACHE_CONTROL_PROGRAM) \
			      $(APACHE_PIDFILE) \
			      $(APACHE_PROGRAM) \
			      $(APACHE_STOP_COMMAND) \
			      $(APACHE_PORT)

# To run a complete iteration, stopping Apache, reconfiguring
# it, and and restarting it, you can run 'make restart [args...]
restart : stop
	$(MAKE) staging
	sudo $(MAKE) install \
	    APACHE_DOC_ROOT=$(APACHE_DOC_ROOT) \
	    APACHE_ROOT=$(APACHE_ROOT) \
	    STAGING_DIR=$(STAGING_DIR) \
	    APACHE_CONF=$(APACHE_CONF) \
	    APACHE_MODULES=$(APACHE_MODULES) \
	    MODS_ENABLED_DIR=$(MODS_ENABLED_DIR) \
	    MODS_AVAILABLE_DIR=$(MODS_AVAILABLE_DIR) \
	    APACHE_USER=$(APACHE_USER) \
	    ENABLE_PROXY=$(ENABLE_PROXY)
	sudo $(APACHE_START)

# Tests that the installed mod_pagespeed server is working.
test :
	CACHE_FLUSH_TEST=on APACHE_DOC_ROOT=$(APACHE_DOC_ROOT) \
		../system_test.sh localhost

# Now hook in the full integration test suite. It needs to be run as root.
# Each test is on it's own line for better diff/merge support.
apache_install_conf :
	$(MAKE) staging_except_module \
	    $(OPT_REWRITE_TEST) \
	    $(OPT_PROXY_TEST) \
	    $(OPT_SLURP_TEST) \
	    $(OPT_MEMCACHED_TEST) \
	    $(OPT_IPRO_PRESERVE_COVERAGE_TEST) \
	    $(OPT_MEMCACHE_COVERAGE_TEST) \
	    $(OPT_PURGING_COVERAGE_TEST) \
	    $(OPT_IUR_COVERAGE_TEST) \
	    $(OPT_SPELING_TEST) \
	    $(OPT_COVERAGE_TRACE_TEST) \
	    $(OPT_STRESS_TEST) \
	    $(OPT_HTTPS_TEST) \
	    $(OPT_SHARED_MEM_LOCK_TEST) \
	    $(OPT_GZIP_TEST) \
	    $(OPT_EXPERIMENT_GA_TEST) \
	    $(OPT_EXPERIMENT_NO_GA_TEST) \
	    $(OPT_ALL_DIRECTIVES_TEST) \
	    $(OPT_PER_VHOST_STATS_TEST) \
	    $(OPT_NO_PER_VHOST_STATS_TEST) \
	    $(OPT_STATS_LOGGING_TEST)
	$(MAKE) install_except_module \
	    $(OPT_REWRITE_TEST) \
	    $(OPT_PROXY_TEST) \
	    $(OPT_SLURP_TEST) \
	    $(OPT_MEMCACHED_TEST) \
	    $(OPT_IPRO_PRESERVE_COVERAGE_TEST) \
	    $(OPT_MEMCACHE_COVERAGE_TEST) \
	    $(OPT_PURGING_COVERAGE_TEST) \
	    $(OPT_IUR_COVERAGE_TEST) \
	    $(OPT_SPELING_TEST) \
	    $(OPT_COVERAGE_TRACE_TEST) \
	    $(OPT_STRESS_TEST) \
	    $(OPT_HTTPS_TEST) \
	    $(OPT_SHARED_MEM_LOCK_TEST) \
	    $(OPT_GZIP_TEST) \
	    $(OPT_EXPERIMENT_GA_TEST) \
	    $(OPT_EXPERIMENT_NO_GA_TEST) \
	    $(OPT_ALL_DIRECTIVES_TEST) \
	    $(OPT_PER_VHOST_STATS_TEST) \
	    $(OPT_NO_PER_VHOST_STATS_TEST) \
	    $(OPT_STATS_LOGGING_TEST)

apache_debug_restart :
	$(APACHE_CONTROL_PROGRAM) restart

apache_debug_stop : stop

# Enables a few ports that are needed by system tests.  This is needed on
# CentOS only to work around barriers erected by SELinux.  See
# http://linux.die.net/man/8/semanage
# http://wiki.centos.org/HowTos/
# SELinux#head-ad837f60830442ae77a81aedd10c20305a811388
#
# The port-list below must be kept in sync with debug.conf.template.  1023 is
# used to test connection-refused handling via modpagespeed.com.  We don't
# actually create a VirtualHost on 1023.
enable_ports_and_file_access :
	set -x; \
	for port in 1023 8081 8082 8084; do \
	    /usr/sbin/semanage port -a -t http_port_t -p tcp $$port || \
	    /usr/sbin/semanage port -m -t http_port_t -p tcp $$port; \
	done
	set -x; \
	for dir in $(MOD_PAGESPEED_CACHE) \
	           $(MOD_PAGESPEED_CACHE)-alt \
	           $(MOD_PAGESPEED_LOG) ; do \
	  mkdir -p $$dir; \
	  chcon -R --reference=$(APACHE_DOC_ROOT) $$dir; \
	done

# Hooks for tests we can only run in development due to needing extensive
# configuration changes in Apache (and potentially different build flags).
# Stubbed out here.
apache_debug_leak_test :
apache_debug_proxy_test :
apache_debug_slurp_test :

APACHE_HTTPS_PORT=
APACHE_DEBUG_PAGESPEED_CONF=$(APACHE_CONF)/pagespeed.conf
INSTALL_DATA_DIR=.

include Makefile.tests
