#!/bin/bash

. `pwd`/versions

sh ./dl

export BUILD_ROOT=`pwd`;
export BUILD_DIR=$BUILD_ROOT/httpd-$VERSION

pcre() {
    cd pcre-$PCRE_VERSION
    export PCRE_DIR=/app/vendor/pcre
    ./configure --prefix=$PCRE_DIR
    make
    make install
    cd ..
}

apache() {
    pcre
    cd httpd-$VERSION
    ./configure --prefix=/app/apache --with-apr=`pwd`/srclib/apr --with-included-apr --with-pcre=$PCRE_DIR --with-mpm=prefork \
    --disable-charset-lite \
    --disable-include \
    --disable-env \
    --disable-setenvif \
    --disable-status \
    --disable-autoindex \
    --disable-asis \
    --disable-cgi \
    --disable-negotiation \
    --disable-imap \
    --disable-actions \
    --disable-userdir \
    --disable-alias \
    --enable-mods-shared \
    --enable-deflate \
    --enable-expies \
    --enable-rewrite \
    --enable-ssl \
    --enable-vhost-alias

    make
    make install
    cd ..
}

installPython() {
    cd ncurses-$NCURSES_VERSION
    ./configure --prefix=/app/vendor/ncurses
    make
    make install
    cd Python-$PYTHON_VERSION
    ./configure --prefix=/app/vendor/python
    make
    make install
    cd ..
}

installGperf() {
    cd gperf-$GPERF_VERSION
    ./configure --prefix=/app/vendor/gperf
    make
    make install
    export PATH=$PATH:/app/vendor/gperf/bin
    cd ..
}

modpagespeed() {
    installPython
    installGperf
    export PATH=$PATH:`pwd`/bin/depot_tools

    cd modpagespeed
    cd src
    make AR.host=`pwd`/build/wrappers/ar.sh AR.target=`pwd`/build/wrappers/ar.sh BUILDTYPE=Release
    cd install
    make APACHE_ROOT=/app/apache \
    APACHE_MODULES=/app/apache/modules \
    APACHE_CONTROL_PROGRAM=/etc/init.d/httpd \
    APACHE_USER=daemon \
    APACHE_DOC_ROOT=/app/www \
    staging
    make install
    cd ..
}

apache
modpagespeed
