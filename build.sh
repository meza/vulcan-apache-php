#!/bin/bash

vulcan update
./download
vulcan build -v -p /app -o "$PWD"/binaries.tgz -s . -c "sh m"
