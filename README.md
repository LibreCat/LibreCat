# LibreCat - the new repository software powered by Catmandu

## This software is under heavy development.

### Prereqs

- Install OS packages as described here: https://github.com/LibreCat/Catmandu/wiki/Installation,

e.g. on debian

```
$ sudo apt-get install build-essential libexpat1-dev \
libssl-dev libxml2-dev libxslt1-dev libgdbm-dev cpanminus
```
- Install [Elasticsearch](http://elasticsearch.org) and [MongoDB](http://mongodb.org)

```
$ sudo apt-get install elasticsearch mongodb
```

- Get the sources

```
# you need the recursive flag to get the git submodules
$ git clone --recursive https://github.com/LibreCat/LibreCat.git
$ cd LibreCat
$ cpanm --notest --installdeps .
```

- Start the webserver

```
$ plackup -E development bin/app.pl
```

and point your browser to http://localhost:5000/.

## Running with Docker

This would be a nice feature. docker/docker-compose setup is still under development.

# TODO

- [ ] How to set up a demo version
- [ ] Provide a Docker container
- [ ] Choose a License
- [ ] Write tests
- [ ] Improve code quality
