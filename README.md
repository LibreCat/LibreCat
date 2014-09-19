# App::Catalog - the new amazing repository backend

## Features

### Template Generator

### Interfaces

- SRU
- OAI
- REST
- (Content negotiation)

### Catalogueing module

backend

### Search module

frontend

## Installation

1) You need

    - a running instance of [Elasticsearch](http://elasticsearch.org)
    - a running instance of [MongoDB](http://mongodb.org)
    - citation style engine?
    - some system packages, see [here for more information](_wiki_)
    - cpanm, the cpan client for perl

2) Now do the following:

    $ git clone *this*
    $ cd *this*
    $ cpanm --notest --installdeps .

3) Congrats, you're done! Now, start the webserver:

    $ perl bin/app.pl


