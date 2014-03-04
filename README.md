[More on Vulcan and heroku builds](http://www.higherorderheroku.com/articles/using-vulcan-to-build-binary-dependencies-on-heroku/)

## Prerequisites

In order to acquire mod_pagespeed, you need svn and git too.

```
gem install vulcan
```

```
vulcan create <your_builder_nodes_name>
```


## Usage

```
./build.sh
```

sit back and watch the compilation - takes about 20 minutes due to the lightning speed of a vulcan node :)

This will result in a packages.tgz, which will contain the /app of the vulcan node.

What you need to do with this is unpack, then
* compress the /apache directory into an apache.tar.gz
* compress the /php directory into a php.tar.gz
* compress the /vendor directory into a vendor.tar.gz

upload the tarballs to the interwebs and feed the links to [my buildpack](https://github.com/meza/heroku-buildpack-php)

### mod_pagespeed

you can get modpagespeed to be compiled. For that, make sure to uncomment the downloadin and uncompression of python, gperf and ncurses in the get_deps, 
and uncomment the get_pagespeed 
in the vulcan_build

