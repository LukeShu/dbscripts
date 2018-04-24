all:
.PHONY: all

check:
	$(MAKE) -C test test
check-coverage:
	rm -rf ${PWD}/coverage
	$(MAKE) -C test test-coverage
.PHONY: check check-coverage

test: check
test-coverage: check-coverage
.PHONY: test test-coverage
