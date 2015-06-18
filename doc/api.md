# PUB -- API Documentation

## Embed Personal Publication List

1. Find yourself at http://pub.uni-bielefeld.de/authorlist and got to your personal publicaition page at PUB.

2. If you like, use the filters on the right hand side to modify your list.

3. Click ```Embed as``` to choose your embedding method.


## Data Dumps

PUB provides data dumps on a weekly basis.

JSON  http://pub.uni-bielefeld.de/pub.json
MODS. http://pub.uni-bielefeld.de/pub.xml

License! CC-whatever.


## Search API

The REST-API provides an easy way for exporting and embedding your publications. The entrypoint for publications is http://pub.uni-bielefeld.de/publication.

The entrypoint for research data is http://pub.uni-bielefeld.de/data.

  ------------------------------------------------------------------------
  Parame Values                            Description
  ter
  ------ --------------------------------- -------------------------------
  `q`    See section on CQL                Contextual Query Language

  `start integers, starting from 0         used for pagination, record
  `                                        number to start from

  `limit integers                          maximum number of publications
  `

  `sort` `{fieldName}.{asc|desc}`          uses the fieldName for sorting,
                                           if sortable, default is
                                           publishingYear.desc

  `ftyp` `js` `iframe` `ajx`               embed list as javascript,
                                           iframe or static html

  `listy                                   \<ul\> tag will have a class
  le`                                      attribute, use for your own css
                                           classes

  `fmt`  `dc` `dc_json` `ris` `json`       Specify an export format, do no
         `yaml` `bibtex` `rdf` `mods`      use in combination with ftyp
         `rtf`

  `style                                   citation style of the
  `                                        publication list
  ------------------------------------------------------------------------

### Example queries

**get all CITEC publications (id=8014655)**

http://pub.uni-bielefeld.de/publication?q=department=8014655

**sort by year, ascending**

http://pub.uni-bielefeld.de/publication?q=department=8014655&sort=publishingYear.asc

**display record no. 100 – 200**

http://pub.uni-bielefeld.de/publication?q=department=8014655&start=100&limit=100

**get all CITEC publications in 2011 and embed as javascript, use APA as
citation style**

http://pub.uni-bielefeld.de/publication?q=department=8014655%20AND%20publishingYear=2011&limit=1000&ftyp=js&style=apa


### Content Negotiation

PUB provides persistent links to scholary works at Bielefeld University.
Typically, these URIs link to a html landing page decribing the resource
and facilitating access, if available, to the self-archived Open Access
copy, the publisher version and other sources referencing the scholary
source (e.g. disciplinary repositories such as [arXiv](http://arxiv.org/)
and [Europe PubMed Central](http://europepmc.org/)). PUB collects and curates
bibliographic metadata about scholary works at Bielefeld University. All publications
are linked to reliable data describing person and organizations at the
university. For this purpose, PUB unifies official data sources, nameley
the Authentication and Authorization Infrastructure and the [Staff and
Department Directory (PEVZ)](http://ekvv.uni-bielefeld.de/pers_publ/publ/Home.jsp) at
Bielefeld University. In particular, PEVZ IDs support browsing and
search on staff and department lists which returns faceted results for
rapid retrieval of desired information for scholary works. In addition
to standard protocols and formats from the Open Repository and Digital
Library Community, PUB Content Negotiation can be used to request a
particular representation of the metadata describing

- a publication `http://pub.uni-bielefeld.de/publication/{id}`

- a person `http://pub.uni-bielefeld.de/person/{ID}`.

A PUB URI normally redirects to the `text/html` presentation of a
resource. For example, the URI

http://pub.uni-bielefeld.de/publication/1609190

redirects to a landing page describing the article, "An Arabidopsis
thaliana T-DNA mutagenized population (GABI-Kat) for flanking sequence
tag-based reverse genetics". Content negotiated requests to
http://pub.uni-bielefeld.de that ask for a content type which isn't
"text/html" will be redirected to the correspondung representation
requested.

For example, a client that wishes to receive BibTeX would make a request
with an accept header listing "application/x-bibtex".

```
$ curl -LH "Accept: application/x-bibtex" http://pub.uni-bielefeld.de/publication/1609190
$ { @article{1609190,
  abstract     = {The GABI-Kat population of T-DNA ...},
  author       = {Rosso, MG and Li, Y and Strizhov, N and Reiss, B and Dekker, K and Weisshaar, Bernd},
  issn         = {0167-4412},
  journal      = {Plant Molecular Biology},
  language     = {English},
  number       = {1},
  pages        = {247--259},
  publisher    = {KLUWER ACADEMIC PUBL},
  title        = {An Arabidopsis thaliana T-DNA mutagenized population (GABI-Kat) for flanking sequence tag-based reverse genetics},
  url          = {http://dx.doi.org/10.1023/B:PLAN.0000009297.37235.4a},
  volume       = {53},
  year         = {2003},
}}
```

PUB supports a number of metadata content types, which are common to
publications, researchers and research units.

- RDF XML (application/rdf+xml)
- MODS (application/mods+xml)
- OAI XML (application/oaidc+xml)
- OAI JSON (application/oaidc+json)
- RIS (application/x-research-info-systems)
- BibTeX (application/x-bibtex)
- JSON (application/json)
- YAML (application/yaml)

## OAI harvesting service

For a nice introduction to OAI-PMH see the [OAI-PMH-Primer](http://oai.base-search.net/index.html#oai-pmh-primer).

**protocol**

> [OAI-PMH,
> v2.0](http://www.openarchives.org/OAI/openarchivesprotocol.html)

base url `http://pub.uni-bielefeld.de/oai`

### Example queries

**get information about this repository**

`http://pub.uni-bielefeld.de/oai?verb=Identify`

**list export formats supported by this repository**

`http://pub.uni-bielefeld.de/oai?verb=ListMetadataFormats`

**list records for an export format**

`http://pub.uni-bielefeld.de/oai?verb=ListRecords&metadataPrefix=oai_dc`

**retrieve the next batch of records based on a resumptionToken (found
in the output of the previous command)**

`http://pub.uni-bielefeld.de/oai?verb=ListRecords&resumptionToken=!!!oai_dc!200`

**list sets provided by this repository**

`http://pub.uni-bielefeld.de/oai?verb=ListSets`

**list records from a set**

`http://pub.uni-bielefeld.de/oai?verb=ListRecords&set={setName}`


## SRU search service

SRU is a standard XML-focused search protocol for Internet search
queries, utilizing CQL (Contextual Query Language), a standard syntax
for representing queries. The base url of this service is http://pub.uni-bielefeld.de/sru.
You can find more on SRU at http://www.loc.gov/standards/sru/index.html.

### Example queries

**search for "analysis" in the basic index**

http://pub.uni-bielefeld.de/sru?version=1.1&operation=searchRetrieve&query=analysis

**search for "analysis" in title and 2012 in publishing year**

http://pub.uni-bielefeld.de/sru?version=1.1&operation=searchRetrieve&query=mainTitle=analysis%20AND%20publishingYear=2012

**sort on publishing year, descending**

http://pub.uni-bielefeld.de/sru?version=1.1&operation=searchRetrieve&query=analysis&sortKeys=publishingYear,,0

**sort on publishing year, ascending**

http://pub.uni-bielefeld.de/sru?version=1.1&operation=searchRetrieve&query=analysis&sortKeys=publishingYear,,1

**start from record no. 100 and display 200**

http://pub.uni-bielefeld.de/sru?version=1.1&operation=searchRetrieve&query=analysis&startRecord=100&maximumRecords=200


## CQL (Contextual Query Language)

CQL, the Contextual Query Language, is a formal language for
representing queries to information retrieval systems. This standard was
developed by the Library of Congress and is widely used in the area of
digital libraries. More information on CQL can be found at http://www.loc.gov/standards/sru/cql/index.html.

### Available indexes

[% index = h.config.store..keys %]
[% FOREACH i IN index %]
**[% i %]**: [% i.operator %]<br />
_[% i.description %]_
[% END %]

## Lists

### Publication types

- Book
- Conference
- Conference Proceeding / Paper
- Dissertation
- Encyclopedia Article
- Journal Article
- Journal
- Newspaper Article
- Patent
- Preprint
- Report
- Research Data
- Translation
- Working Paper
- Bielefeld Doctoral Thesis
- Bielefeld Bachelor Thesis
- Bielefeld Master Thesis
- Bielefeld Post-Doctoral Habilitation

### Publication status

- published
- eprint
- inpress
- submitted
- unpublished
