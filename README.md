# LibreCat - the new amazing repository

## Installation

### Prereqs

install OS packages as described here: https://github.com/LibreCat/Catmandu/wiki/Installation, e.g. on debian

```
$ sudo apt-get install build-essential libexpat1-dev \
libssl-dev libxml2-dev libxslt1-dev libgdbm-dev imagemagick cpanminus
```

install [Elasticsearch](http://elasticsearch.org) and [MongoDB](http://mongodb.org)

```
$ sudo apt-get install elasticsearch mongodb
```


### Get the sources

```
# you need the resursive flag to get the git submodules
$ git clone --recursive git@gitlab.ub.uni-bielefeld.de:vpeil/app-repository.git

$ cd app-repository

# --notest is just for a quick install
$ cpanm --notest --installdeps .
```

### Congrats, you're done! Now, start the webserver

```
$ plackup -E development bin/app.pl
```

and point your browser to http://localhost:5000/.
