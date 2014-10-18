
all: test

sift.exe:
	dub build

test: sift.exe
	(cd tests; dub test)

clean:
	@find . -name "*.o" -exec rm {} \;

.PHONY: test
