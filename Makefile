all:
.PHONY: all

test:
	$(MAKE) -C test test

test-coverage:
	rm -rf ${PWD}/coverage
	$(MAKE) -C test test-coverage

.PHONY: test test-coverage
