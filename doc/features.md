# Features

*librecat* is a repository application which has as its key features

- institutional repository
- publication list manager for reseachers
- institutional research data archive.

## Technical

The repository application *librecat* has been developed by the [LibreCat Group](http://librecat.org).
As such it is completely based on the *Catmandu* framework.
This software uses Perl, Perl-Dancer, JS, HTML5, CSS3 as its key ingredients.
It uses [elasticsearch](http://elasticsearch.org) as a super-fast, super-flexible metadata store.
With ~6,500 lines of Perl code is the most lightweight repository application, as far as we know.

## Design

*librecat* provides a nice user-friendly and responsive web-design via the *bootstrap* framework.

## APIs

*librecat* includes a number of standardized APIs common to the library community as well as for the web community.

- OAI
    - OAI-DC
    - MODS
    - Epicur
    - xMetaDissplus

- SRU
    - MODS
    - OAI-DC

- REST / content negotiation
    - JSON
    - YAML
    - BibTeX
    - RDF
    - etc.

## Data Imports

Data ingest is mainly done by importing metadata form other sources:

- Web of Science
- Europe PMC
- arxiv.org
- inspirehep.org

This features is easily extendible as long as the source repository provides a nice API.

## Rights/Roles Management

...


## Publications and Research Data

...
