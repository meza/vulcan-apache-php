#!/bin/bash

echo "Cleaning directory"
rm -rf *.tar.gz
rm -rf *.tgz

echo "Updating vulcan"
vulcan update
#sh ./get_pagespeed

echo "Building the package"
time vulcan build -v -p /app -o "$PWD"/package.tgz -s . -c "sh vulcan_build"
# > ../output.log 2> ../error.log
