
build: mulang

test: FORCE mulang
	(cd test/1; ../../mulang)
	./test/1/var/out.sh > test/1/var/result.txt
	diff -u test/1/etc/expected.txt test/1/var/result.txt
	echo OK

mulang: var/makefile
	./etc/mulang-last
	cp var/out.sh mulang

FORCE:

