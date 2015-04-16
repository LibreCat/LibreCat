# Specifications and routes layout

## prefix

loads the whole app with the prefix, all subsequent routes are relative to this prefix

```perl
load_app 'App', prefix => '/myPUB';
```

## Module App::Catalog

### /

Shows author's publication list + author's profile.

### /login

After successful login:
```perl
redirect '/';
```

### /logout
```perl
# redirect to pub start page
redirect 'h->config->{host}';
```

## Module App::Catalog::Publication

Handles all operations concerning publication items
prefix '/record' ??

### get '/record/new'

prints empty form or or pushes identifier to Import module

### get '/record/edit/:id'

opens form to be edited

### post '/record/update'

validate and save data to db, redirect to '/'

### post '/return/:id'

returns a record, redirect to /update with params needed

### post '/publish/:id'

publishes a record, redirect to /update with params needed

### del '/delete/:id'

deletes record, admins only, confirmation required


## Module App::Catalog::Import

### get '/import/:id'

classify id, load data from specified source, show in template, DO NOT SAVE IN DB AT THIS STAGE

### post '/import/bibtex'

allow for admins only? or set maximum number of records?


## Module App::Catalog::Person

### post '/person/preferences'

set citationstyle and sorting, allowed for user

### post '/post/authorid'

set external author ids, allowed for user

---

## Module App::Catalog::Admin

### get '/admin'

what should appear here?

### get '/admin/accounts/search'

search accounts

### get '/admin/accounts/edit/:id'

edit account with :id

### post '/admin/accounts/update'

update account record

---

# Data model

## basic fields
```yaml
---
_id: unique record identifier
date_updated: 2014-10-14T01:00
date_created: 2014-10-13T01:00
record_creator: mmustermann
type: publication type
title: title of the publication
alternative_title:
	- alternative title
year: 2014
author:
	-
		first_name: "Gerhard"
		last_name: "Sagerer"
		full_name: "Sagerer, Gerhard"
		id: "123456"
first_author: "Lastname, Firstname"
editor: see author
translator: see author
supervisor: see author
file:
	-
		file_name: "hello.pdf"
		file_id: 123456
		content_type: "application/pdf"
		access_level: "open_access"|"local"|"closed"
		date_updated: "2014-04-23T12:00:00"
		date_created: "2014-04-23T12:00:00"
		checksum: 1423534q566768tz
		file_size: 3.4 MB
		language: eng
		creator: bisid
		open_access: 1|0
		request_a_copy: 1|0
		embargo: YYYY-MM-DD
		year_last_uploaded: 2014
		title: "some title"
		description: "some description"
		relation: "main_file"|"supplementary_material"...
		fileOrder: 000
data_reuse_license: "pddl"
open_data_release: 1|0
other_data_license: "text"
accept: 1|0
doi: 10.214/test
ddc:
	- 530
	- 004
	- 610

keyword:
	- keyword1
	- keyword2
language:
	-
	  iso: ger
	  name: German
	-
	  iso: eng
	  name: English
original_language:
	-
	  iso: ger
	  name: German
	-
	  iso: eng
	  name: English
department:
	-
		name: "Faculty of Physics"
		id: 123456
		tree:
			- 98765
			- 54321
project:
    -
        name: "project name"
        id: 29383
thematic_area: diversity|other
status: public|private|submitted|returned
publication_status: inPress|unpublished|submitted|published
publication_identifier:
	issn: ["1234", "23445"]
	eissn: ["see issn"]
	isbn: ["see issn"]
	eisbn: ["see issn"]
urn: "urn:nbn:de...."
publisher: "Springer"
place: "Bielefeld"
publication: "Journal of genetics"
abstract:
	-
		lang: eng
		text: "This is an abstract"
	-
		lang: ger
		text: "Das ist eine Zusammenfassung"
extern: 0|1
popular_science: 0|1
quality_controlled: 0|1
article_type: original|review|letter_note
# problem in template
page: 45-70
edition: 2
corporate_editor:
	- "Gesellschaft für Soziologie"
	- "Institut ...."
series_title: "KI Serie"
volume: 3
issue: 2
conference:
	name: "ELAG 2014"
	location: "Bath, UK"
	start_date: "2014-05-20"
	end_date: "2014-05-23"
publishing_date: "2014-04-23"
ipn: 21314
ipc: 2344
report_number: 18
email: "me@example.com"
defense_date: "2014-04-23"
link: ["www.example.com", "www.example2.com"]
external_id:
    isi: asldkf
    arxiv: sdfdsf
	pmid: dfsdf
	inspire: asldfjasl
	ahf: sksks
	scoap3: sklslsdj
	phillister: sdklfjdslf
	opac: lsdfj
	fp7: fp7/sdfkls
	fp6: fp6/sdlfkjsd
genbank: []
nasc: []
pacs_class: []
msc_class: []
ccs_class: []
message: "Just a message"
ubi_funded: 0|1
ec_funded: 0|1
related_material:
	link:
	  -
	    url: "www.example.com"
		title: "test"
		description: "This describes something"
		relation: "supplementary_file"
	record:
	  -
	    id: 123456
		relation: is_part_of
```

## project fields
```yaml
---
_id: unique record identifier
date_updated: 2014-10-14T01:00
date_created: 2014-10-13T01:00
start_date: 2014-01-01
end_date: 2014-12-31
name: "text"
acronym: "TEXT"
alternative_name: "text"
url: "http://www.bla.de"
grant_number: "1234"
psp_element: "1234"
description: "this is a description"
active: 1|0
department:
	-
		name: "Faculty of Physics"
		id: 123456
		tree:
			- 98765
			- 54321
owner:
  full_name: bla
  first_name: bla
  last_name: bla
  id: 12234
designated_editor:
  full_name: bla
  first_name: bla
  last_name: bla
  id: 12234
principal_investigator:
  -
    full_name: bla
    first_name: bla
    last_name: bla
    id: 12234
member:
  -
    full_name: bla
    first_name: bla
    last_name: bla
    id: 12234
cooperator:
  - asdfas
  - ...
funder:
  - asdfas
  - ...
funded: 1|0
call_identifier:asdfas
sc39: 1|0

## award fields
## db.award
date_updated: 2014-01-01T01:00
_id: AW1
title: "Award Title"
type: preis|auszeichnung|akademie

## db.data
date_updated: 2014-01-01T01:00
_id: WP1
award_id: "AW1"
description: "dies ist eine beschreibung"
description_en: "this is a description"
proof: "http://www.leopoldina.org/de/mitglieder/mitgliederverzeichnis/member/707/"
title: "titel"
organization: "Uni Konstanz"
year: "2014"
honoree:
  first_name: "Alfred"
  last_name: "Pühler"
  full_name: "Pühler, Alfred"
  title: "Prof. Dr."
  id: "21937"
department:
  -
    name: "Faculty of Physics"
    id: 123456
    tree:
      - 98765
      - 54321
einrichtung:
  -
    name: "Faculty of Physics"
    id: "12345"
    tree:
      - 122345
      - 148234
uni_member: 1|0
former_member: ja | nein | emeritiert | in Rente
other_university: "Ludwig-Maximilians-Universität München"
url: "http://www.mpib-berlin.mpg.de/de/mitarbeiter/ute-frevert"
extern: 1|0 #"awardedWhileNotUnibi"
comment: "some message or comment"
