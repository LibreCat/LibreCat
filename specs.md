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

