#!/bin/bash

vulcan update
./download
vulcan build -v -p /app/comp -o "$PWD"/binaries.tgz -s . -c "sh m"
