#!/bin/bash

vulcan update
#sh ./get_pagespeed
time vulcan build -v -p /app -o "$PWD"/package.tgz -s . -c "sh vulcan_build"
# > ../output.log 2> ../error.log
