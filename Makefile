usage:
	@echo "usage: [ NETWORK_TEST=1 ] make TARGET"
	@echo
	@echo "targets:"
	@echo "  generate"
	@echo "  update"
	@echo "  test"
	@echo "  cover [ FILE=<path> ]"

generate:
	carton exec bin/librecat generate forms
	carton exec bin/librecat generate departments

update:
	git pull --tags origin master
	carton install
	carton exec bin/librecat generate forms
	carton exec bin/librecat generate departments
	./index.sh reindex
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
	prove -l -j 1 -r t
