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
		title: "Prof. Dr."
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
		access_level: "openAccess"
		date_updated: "2014-04-23T12:00:00"
		date_created: "2014-04-23T12:00:00"
		checksum: 1423534q566768tz
		file_size: 3.4 MB
		language: eng
		creator: bisid
		open_access: 1|0
		year_last_uploaded: 2014
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
status: public|private|submitted|returned
publication_status: inPress|unpublished|submitted|published
publication_identifier:
	issn: ["1234", "23445"]
	eissn: see issn
	isbn: see issn 
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
page:
	start: 20
	end: 25
	count: 230
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
report_number 18
email: "me@example.com"
defense_date: "2014-04-23"
link: ["www.example.com", "www.example2.com"]
external_id:
    isi:
        id: asldkf
        prefix_id: "ISI:asldkf"
	arxiv:
	    id: sdfdsf
	    prefix_id: "arXiv:sdfdsf"
	pumid:
	    id: dfsdf
	    prefix_id: "MEDLINE:dfsdf"
	inspire:
	    id: asldfjasl
	    prefix_id: "INSPIRE:asldfjasl"
	ahf:
	    id: sksks
	    prefix_id: "AHF:sksks"
	scoap3:
	    id: sklslsdj
	    prefix_id: "SCOAP3:sklslsdj"
	phillister:
	    id: sdklfjdslf
	    prefix_id: "PhilLister:sdklfjdslf"
	opac:
	    id: lsdfj
	    prefix_id: "UB-OPAC:lsdfj"
	fp7:
	    id: fp7/sdfkls
	    prefix_id: fp7/sdfkls
	fp6:
	    id: fp6/sdlfkjsd
	    prefix_id: fp6/sdlfkjsd
	genbank: []
	nasc: []
message: "Just a message"
ubi_funded: 0|1
ec_funded: 0|1
related_material:
	-
		type: "supplementary"
		link:
			url: "www.example.com"
			title: "test"
			description: "This describes something"
		file:
			file_name: "file.jpg"
			file_id: 12345
			description: "This describes something"
			date_updated: "2014-04-23"
			date_created: "2014-04-23"
			title: "Title"
			creator: login_name
			access_level: openAccess
			content_type: application/pdf
			checksum: 32erjweoiru90
			file_size: 3.4 MB
		record:
			id: 123456
			relation: is_part_of
```
