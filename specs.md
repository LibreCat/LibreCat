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
type: publication type
title: title of the publication
alternativeTitle: alternative title
year: 2014
author:
	- 
		firstName: "Gerhard"
		lastName: "Sagerer"
		title: "Prof. Dr."
		fullName: "Sagerer, Gerhard"
		id: "123456"
editor: see author
translator: see author
supervisor: see author
file:
	-
		fileName: "hello.pdf"
		fileId: 123456
		contentType: "application/pdf"
		accessLevel: "openAccess"
		date_updated: "2014-04-23T12:00:00"
		date_created: "2014-04-23T12:00:00"
		checksum: 1423534q566768tz
		fileSize: 3.4 MB
		language: eng
		creator: bisid
doi: 10.214/test
ddc:
	- 530
	- 004
	- 610

keyword:
	- keyword1
	- keyword2
language:
	- ger
	- eng
department/project/researchGroup:
	-
		name: "Faculty of Physics"
		id: 123456
		tree:
			- 98765
			- 54321
status: public|private|submitted|returned
publicationStatus: inPress|unpublished|submitted|published
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
external: 0|1
popularScience: 0|1
qualityControlled: 0|1
pages:
	start: 20
	end: 25
	count: 230
edition: 2
corporateEditor:
	- "Gesellschaft für Soziologie"
	- "Institut ...."
seriesTitle: "KI Serie"
volume: 3
issue: 2
conference:
	name: "ELAG 2014"
	location: "Bath, UK"
	startDate: "2014-05-20"
	endDate: "2014-05-23"
publishingDate: "2014-04-23"
ipn: 21314
ipc: 2344
reportNumber 18
email: "me@example.com"
defenseDate: "2014-04-23"
link: ["www.example.com", "www.example2.com"]
arxiv: sdfdsf
pmid: dfsdf
inspire:
wos:
genbank: []
nasc: []
message: "Just a message"
ubiFunded: 0|1
relatedMaterial:
	-
		type: "supplementary"
		link:
			url: "www.example.com"
			title: "test"
			description: "This describes something"
		file:
			fileName: "file.jpg"
			fileId: 12345
			date_updated: "2014-04-23"
			date_created: "2014-04-23"
			title: "Title"
			creator: bisid
			accessLevel: openAccess
			contentType: application/pdf
			checksum: 32erjweoiru90
			fileSize: 3.4 MB
		record:
			id: 123456
```

## TODO

Review?







