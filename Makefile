.SUFFIXES:

.PHONY: generate update cover test tidy

usage:
	@echo "usage: [ NETWORK_TEST=1 ] make TARGET"
	@echo
	@echo "targets:"
	@echo "  generate"
	@echo "  update [ VERSION=<version> ]"
	@echo "  tidy"
	@echo "  test"
	@echo "  cover [ FILE=<path> ]"

generate:
	carton exec -- bin/librecat generate forms
	carton exec -- bin/librecat generate departments

update:
	git checkout master
	git pull --tags origin master
ifeq ($(strip $(VERSION)),)
	echo "No VERSION specified; checking out HEAD of master branch"
else
	git checkout $(VERSION)
endif
	carton install
	carton exec -- bin/librecat generate forms
	carton exec -- bin/librecat generate departments
	carton exec -- bin/librecat index switch
	echo "Update complete!"

# Explicit need -j 1 parallel tests will put databases in an
# inconsistent state
cover:
	cover -delete
ifeq ($(strip $(FILE)),)
	cover -t +select ^lib +ignore ^ -make 'prove -Ilib -j 1 -r t; echo'
else
	cover -t +select ^lib +ignore ^ -make 'prove -Ilib -j 1 -r $(FILE); echo'
endif

test:
	carton exec -- prove -l -j 1 -r t

tidy:
	tidyall -r lib t
