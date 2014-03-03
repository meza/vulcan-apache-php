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

sit back and watch the compilation - takes about 40 minutes due to the lightning speed of a vulcan node :)
